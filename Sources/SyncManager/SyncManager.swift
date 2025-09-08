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
    private let settings: Settings
    private var timer: Timer?
    private let queue = DispatchQueue(label: "SyncManager.Queue")

    public enum Status { case idle, syncing, error(String) }
    public private(set) var status: Status = .idle

    public init(beeminder: BeeminderClient, bear: BearClient, store: PersistenceType, settings: Settings) {
        self.beeminder = beeminder
        self.bear = bear
        self.store = store
        self.settings = settings
    }

    public func start() {
        scheduleTimer(minutes: settings.syncFrequencyMinutes)
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }

    public func scheduleTimer(minutes: Int) {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(minutes * 60), repeats: true) { [weak self] _ in
            Task { await self?.syncNow() }
        }
    }

    @discardableResult
    public func syncNow() async -> Bool {
        status = .syncing
        do {
            // Fetch Bear data (stub for now)
            let notes = try await bear.fetchNotesModifiedToday(filteredByTags: settings.trackTags)
            let today = Self.today()
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
            return true
        } catch {
            LOG(.error, "Sync failed: \(error)")
            status = .error("\(error)")
            return false
        }
    }

    private static func today() -> String {
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.timeZone = TimeZone(secondsFromGMT: 0)
        df.dateFormat = "yyyy-MM-dd"
        return df.string(from: Date())
    }
}
