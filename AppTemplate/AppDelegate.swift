import AppKit
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
        // TEMP DEBUG: confirm launch path (modal)
        LOG(.info, "AppDelegate.applicationDidFinishLaunching")
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "BearMinder Launched"
        alert.informativeText = "If you don't see a 🐻 in the menu bar, we'll adjust rendering next."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        _ = alert.runModal()

        // Seed credentials from local/credentials.json (gitignored) on first launch if available
        LocalConfigLoader.seedIfNeeded()

        // Initialize core
        let username = UserDefaults.standard.string(forKey: "beeminder.username") ?? ""
        let goal = UserDefaults.standard.string(forKey: "beeminder.goal") ?? ""
        let keychain = KeychainStore()
        beeminder = BeeminderClient(username: username, goal: goal) {
            (try? keychain.getPassword(account: "token", service: "beeminder")) ?? ""
        }
        bear = BearClient {
            (try? keychain.getPassword(account: "token", service: "bear")) ?? ""
        }
        store = CoreDataPersistence(storeURL: CoreDataPersistence.defaultStoreURL())
        let settings = Settings(beeminderUsername: username, beeminderGoal: goal)
        syncManager = SyncManager(beeminder: beeminder, bear: bear, store: store, settings: settings)

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
        let comment = summary + "\n\n🐻 via Bear → Beeminder"
        let dp = BeeminderDatapoint(value: totalDelta, comment: comment, requestID: "bear-sync-\(today)", timestamp: Date().timeIntervalSince1970)
        do {
            _ = try await beeminder.postDatapoint(dp, perform: true)
            LOG(.info, "Posted datapoint value=\(totalDelta) to Beeminder goal=\(goal)")
        } catch {
            LOG(.error, "Failed posting datapoint: \(error)")
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
}
