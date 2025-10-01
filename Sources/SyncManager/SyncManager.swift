import Foundation
import Models
import BeeminderClient
import BearClient
import Persistence
import Logging

public final class SyncManager {
    private let beeminder: BeeminderClient
    private let bear: BearClient
    private let store: PersistenceType
    private var settings: Settings
    private var timer: Timer?
    private var dsTimer: DispatchSourceTimer?
    public private(set) var lastSyncAt: Date?
    public var performer: (() async -> Bool)?
    public private(set) var nextFireAt: Date?
    public private(set) var currentIntervalMinutes: Int = 0
    private let queue = DispatchQueue(label: "SyncManager.Queue")

    public enum Status { case idle, syncing, error(String) }

    public private(set) var status: Status = .idle
    public func updateTags(_ tags: [String]?) {
        settings.trackTags = tags
    }

    public init(beeminder: BeeminderClient, bear: BearClient, store: PersistenceType, settings: Settings) {
        self.beeminder = beeminder
        self.bear = bear
        self.store = store
        self.settings = settings
    }

    public func start() {
        let minutes = UserDefaults.standard.integer(forKey: "sync.frequency.minutes")
        let freq = minutes > 0 ? minutes : settings.syncFrequencyMinutes
        scheduleTimer(minutes: (freq > 0 ? freq : 60))
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
        dsTimer?.setEventHandler(handler: nil)
        dsTimer?.cancel()
        dsTimer = nil
    }

    public func scheduleTimer(minutes: Int) {
        stop()
        currentIntervalMinutes = minutes
        let interval = TimeInterval(minutes * 60)
        nextFireAt = Date().addingTimeInterval(interval)
        // Use DispatchSourceTimer for robustness across run loop modes
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + interval, repeating: interval, leeway: .seconds(30))
        t.setEventHandler { [weak self] in
            guard let self = self else { return }
            Task { await self.syncNow() }
            self.nextFireAt = Date().addingTimeInterval(interval)
        }
        dsTimer = t
        t.resume()
    }

    public func updateFrequency(minutes: Int) {
        scheduleTimer(minutes: minutes)
    }

    @discardableResult
    public func syncNow() async -> Bool {
        status = .syncing
        NotificationCenter.default.post(name: .syncStatusDidChange, object: self)

        // Prefer external performer when provided (real app flow)
        if let performer = performer {
            let ok = await performer()
            status = ok ? .idle : .error("performer failed")
            if ok { lastSyncAt = Date() }
            NotificationCenter.default.post(name: .syncStatusDidChange, object: self)
            return ok
        }

        do {
            // Fetch Bear data (stub for now)
            let notes = try await bear.fetchNotesModifiedToday(filteredByTags: settings.trackTags)
            let today = DateUtility.today()
            var totalWords = 0
            var modifiedCount = 0

            for note in notes {
                modifiedCount += 1
                let prev = try store.loadNoteTracking(noteID: note.id, date: today)?.currentWordCount ?? 0
                let current = note.wordCount
                totalWords += max(0, current - prev)
                try store.saveNoteTracking(NoteTracking(noteID: note.id, date: today, previousWordCount: prev, currentWordCount: current))
            }

            var snapshot = try store.loadDailySnapshot(for: today) ?? DailySnapshot(date: today, totalWords: 0, notesModified: 0, topTags: [], syncStatus: "pending", lastUpdated: Date())
            snapshot.totalWords += totalWords
            snapshot.notesModified = modifiedCount
            snapshot.lastUpdated = Date()
            try store.saveDailySnapshot(snapshot)

            let comment = "📝 \(snapshot.totalWords) words across \(snapshot.notesModified) notes\n\n🐻 via Bear → Beeminder"
            let dp = BeeminderDatapoint(value: snapshot.totalWords, comment: comment, requestID: "bear-sync-\(today)", timestamp: Date().timeIntervalSince1970)
            _ = try await beeminder.postDatapoint(dp, perform: false)
            status = .idle
            lastSyncAt = Date()
            NotificationCenter.default.post(name: .syncStatusDidChange, object: self)
            return true
        } catch {
            LOG(.error, "Sync failed: \(error)")
            status = .error("\(error)")
            NotificationCenter.default.post(name: .syncStatusDidChange, object: self)
            return false
        }
    }
}
