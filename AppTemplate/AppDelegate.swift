import AppKit
import ServiceManagement
import UserNotifications
import Models
import BeeminderClient
import BearClient
import Persistence
import SyncManager
import Logging
import KeychainSupport
import Config

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusController: StatusItemController!
    private var settingsController: SettingsWindowController!
    var callbackCoordinator = BearCallbackCoordinator()
    private var integrationManager = BearIntegrationManager()

    // Core components
    private var beeminder: BeeminderClient!
    private var bear: BearClient!
    private var store: PersistenceType!
    private var syncManager: SyncManager!

    func applicationDidFinishLaunching(_ notification: Notification) {
        LOG(.info, "AppDelegate.applicationDidFinishLaunching")

        // Seed credentials from local/credentials.json (gitignored) on first launch if available
        LocalConfigLoader.seedIfNeeded()

        // Initialize core
        let username = UserDefaults.standard.string(forKey: "beeminder.username") ?? ""
        let goal = UserDefaults.standard.string(forKey: "beeminder.goal") ?? ""
        let keychain = KeychainStore()
        let combined = try? keychain.getCombinedTokens()
        beeminder = BeeminderClient(username: username, goal: goal) {
            if let c = combined, !c.beeminder.isEmpty { return c.beeminder }
            return (try? keychain.getPassword(account: "token", service: "beeminder")) ?? ""
        }
        bear = BearClient {
            if let c = combined, !c.bear.isEmpty { return c.bear }
            return (try? keychain.getPassword(account: "token", service: "bear")) ?? ""
        }
        store = CoreDataPersistence(storeURL: CoreDataPersistence.defaultStoreURL())
        let settings = Settings(beeminderUsername: username, beeminderGoal: goal)
        syncManager = SyncManager(beeminder: beeminder, bear: bear, store: store, settings: settings)
        // Make scheduled syncs use the same real flow as manual syncs
        syncManager.performer = { [weak self] in
            await self?.performRealSyncNow()
            return true
        }

        // UI controllers
        statusController = StatusItemController(syncManager: syncManager) { [weak self] action in
            switch action {
            case .syncNow:
                Task { await self?.performRealSyncNow() }
            case .openBeeminder:
                if let url = URL(string: "https://www.beeminder.com/") { NSWorkspace.shared.open(url) }
            case .openSettings:
                self?.showSettings()
            case .quit:
                NSApp.terminate(nil)
            }
        }
        settingsController = SettingsWindowController()

        statusController.install()
        LOG(.info, "StatusItemController.install invoked")
        syncManager.start()

        // URL callbacks from Bear x-callback-url
        registerURLHandler()

        // Observe settings save to apply changes live
        NotificationCenter.default.addObserver(forName: .settingsDidSave, object: nil, queue: .main) { [weak self] note in
            guard let self = self else { return }
            let minutes = (note.userInfo?["minutes"] as? Int) ?? 60
            let tags = note.userInfo?["tags"] as? [String]
            let startAtLogin = (note.userInfo?["startAtLogin"] as? Bool) ?? false
            self.syncManager.updateFrequency(minutes: minutes)
            self.syncManager.updateTags(tags)
            self.applyStartAtLogin(startAtLogin)
            LOG(.info, "Applied settings: minutes=\(minutes) tags=\(tags ?? []) startAtLogin=\(startAtLogin)")
        }
    }

    private func showSettings() {
        settingsController.show()
    }

    // MARK: - Real Sync Flow using BearIntegrationManager
    private func performRealSyncNow() async {
        guard let username = UserDefaults.standard.string(forKey: "beeminder.username"), !username.isEmpty,
              let goal = UserDefaults.standard.string(forKey: "beeminder.goal"), !goal.isEmpty else {
            LOG(.warning, "Missing Beeminder username/goal in UserDefaults")
            _ = await syncManager.syncNow() // fallback to core dry-run
            return
        }
        let keychain = KeychainStore()
        let bearToken = (try? keychain.getPassword(account: "token", service: "bear")) ?? ""
        if bearToken.isEmpty {
            LOG(.warning, "Missing Bear token in Keychain")
            _ = await syncManager.syncNow()
            return
        }

        // 1) Fetch notes via Bear x-callback-url (await callback)
        let notes = await integrationManager.fetchNotesModifiedToday(token: bearToken)
        LOG(.info, "BearIntegration returned notes count=\(notes.count)")

        // 2) Update local snapshot and note tracking (delta calc)
        let today = Self.today()
        let yesterday = Self.yesterday()
        var totalDelta = 0
        var modified = 0
        for note in notes {
            modified += 1
            // Stable baseline for "today" is yesterday's end-of-day count if available; otherwise 0.
            // If a today's record exists with previous==current and there's no yesterday record,
            // it means we incorrectly initialized baseline earlier; fix it to 0.
            let yest = try? store.loadNoteTracking(noteID: note.id, date: yesterday)
            let todayTrack = try? store.loadNoteTracking(noteID: note.id, date: today)
            var baseline = yest?.currentWordCount ?? 0
            if baseline == 0, let t = todayTrack, t.previousWordCount == t.currentWordCount {
                baseline = 0 // explicitly baseline to 0 for notes created today
            } else if baseline == 0, todayTrack == nil {
                baseline = 0
            }
            let delta = max(0, note.wordCount - baseline)
            totalDelta += delta
            LOG(.info, "Note id=\(note.id.prefix(8)) title=\(note.title) wordCount=\(note.wordCount) baseline=\(baseline) delta=\(delta)")
            // Persist today's snapshot with yesterday baseline and current count
            try? store.saveNoteTracking(NoteTracking(noteID: note.id, date: today, previousWordCount: baseline, currentWordCount: note.wordCount))
        }
        LOG(.info, "Total delta for today=\(totalDelta) across notesModified=\(modified)")
        var snapshot = (try? store.loadDailySnapshot(for: today)) ?? DailySnapshot(date: today, totalWords: 0, notesModified: 0, topTags: [], syncStatus: "pending", lastUpdated: Date())
        snapshot.totalWords = totalDelta
        snapshot.notesModified = modified
        snapshot.lastUpdated = Date()
        try? store.saveDailySnapshot(snapshot)

        // 3) Post to Beeminder (real POST)
        // If there's no new writing today, do not post (prevents overwriting a positive datapoint with 0).
        guard totalDelta > 0 else {
            LOG(.info, "No new words today; skipping Beeminder post")
            return
        }
        // Use only today's delta so repeated syncs update the same day’s datapoint idempotently.
        // Build a richer summary line and include newlines (will be form-url-encoded)
        let uniqueTags = Set(notes.flatMap { $0.tags }).count
        let summary = "📝 \(totalDelta)w | 📚 \(snapshot.notesModified) notes | 🏷️ \(uniqueTags) tags"
        let comment = summary + " • 🐻 via Bear → Beeminder"
        let dp = BeeminderDatapoint(value: totalDelta, comment: comment, requestID: "bear-sync-\(today)", timestamp: Date().timeIntervalSince1970)
        do {
            _ = try await beeminder.postDatapoint(dp, perform: true)
            LOG(.info, "Posted datapoint value=\(totalDelta) to Beeminder goal=\(goal)")
            // Flush any queued datapoints after a successful post
            try await flushQueuedDatapoints()
            // Reset failure streak on success
            UserDefaults.standard.set(0, forKey: "post.failure.streak")
        } catch {
            LOG(.error, "Failed posting datapoint: \(error)")
            // Enqueue for later retry and notify user discreetly
            try? store.enqueueDatapoint(dp)
            let streak = (UserDefaults.standard.integer(forKey: "post.failure.streak") + 1)
            UserDefaults.standard.set(streak, forKey: "post.failure.streak")
            if streak >= 2 { // notify only after 2+ consecutive failures
                notify(title: "BearMinder", body: "Queued today's datapoint to retry later.")
            }
        }
    }

    private static func today() -> String {
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.timeZone = TimeZone(secondsFromGMT: 0)
        df.dateFormat = "yyyy-MM-dd"
        return df.string(from: Date())
    }

    private static func yesterday() -> String {
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.timeZone = TimeZone(secondsFromGMT: 0)
        df.dateFormat = "yyyy-MM-dd"
        guard let y = Calendar(identifier: .gregorian).date(byAdding: .day, value: -1, to: Date()) else { return today() }
        return df.string(from: y)
    }

    // Silence secure restorable state warning during development
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }

    // MARK: - Login Item
    private func applyStartAtLogin(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled { try SMAppService.mainApp.register() }
                else { try SMAppService.mainApp.unregister() }
            } catch {
                LOG(.error, "Failed to update Start at Login: \(error)")
            }
        } else {
            LOG(.warning, "Start at Login requires macOS 13+. Skipping.")
        }
    }

    // MARK: - Notifications & Offline Queue
    private func notify(title: String, body: String) {
        if #available(macOS 10.14, *) {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
                guard granted else { return }
                let content = UNNotificationContent()
                let mutable = UNMutableNotificationContent()
                mutable.title = title
                mutable.body = body
                let req = UNNotificationRequest(identifier: UUID().uuidString, content: mutable, trigger: nil)
                UNUserNotificationCenter.current().add(req, withCompletionHandler: nil)
            }
        }
    }

    private func flushQueuedDatapoints() async throws {
        let queued = (try? store.dequeueAllDatapoints()) ?? []
        guard !queued.isEmpty else { return }
        var sent = 0
        for q in queued {
            do {
                _ = try await beeminder.postDatapoint(q, perform: true)
                sent += 1
            } catch {
                // Re-enqueue remaining and stop
                try? store.enqueueDatapoint(q)
                for r in queued.dropFirst(sent + 1) { try? store.enqueueDatapoint(r) }
                break
            }
        }
        if sent > 0 { notify(title: "BearMinder", body: "Sent \(sent) queued datapoint(s).") }
    }
}
