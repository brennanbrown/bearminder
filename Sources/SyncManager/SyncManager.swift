import Foundation
import Models
import BeeminderClient
import BearClient
import Persistence
import Logging

public final class SyncManager {
    // MARK: - Type Definitions
    
    public enum Status {
        case idle
        case syncing
        case error(String)
    }
    
    // MARK: - Properties
    
    private let beeminder: BeeminderClient
    private let bear: BearClient
    private let store: PersistenceType
    private var settings: Settings
    private let queue = DispatchQueue(label: "SyncManager.Queue")
    
    // Timer state
    private var timer: Timer?
    private var dsTimer: DispatchSourceTimer?
    
    // Retry/backoff state
    private var consecutiveFailures: Int = 0
    private let maxRetries: Int = 3
    private let baseBackoffSeconds: TimeInterval = 5.0
    
    // Public properties
    public private(set) var lastSyncAt: Date?
    public private(set) var nextFireAt: Date?
    public private(set) var currentIntervalMinutes: Int = 0
    public private(set) var status: Status = .idle
    
    // Callback property
    public var performer: (() async -> Bool)?
    // MARK: - Initialization
    
    public init(beeminder: BeeminderClient, bear: BearClient, store: PersistenceType, settings: Settings) {
        self.beeminder = beeminder
        self.bear = bear
        self.store = store
        self.settings = settings
    }
    
    // MARK: - Public Methods
    
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
    
    public func updateFrequency(minutes: Int) {
        scheduleTimer(minutes: minutes)
    }
    
    public func updateTags(_ tags: [String]) {
        settings.trackTags = tags
    }
    
    // MARK: - Timer Management
    
    private func scheduleTimer(minutes: Int) {
        stop()
        currentIntervalMinutes = minutes
        let interval = TimeInterval(minutes * 60)
        nextFireAt = Date().addingTimeInterval(interval)
        
        // Use DispatchSourceTimer for robustness across run loop modes
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(
            deadline: .now() + interval,
            repeating: interval,
            leeway: .seconds(30)
        )
        
        t.setEventHandler { [weak self] in
            guard let self = self else { return }
            Task { await self.syncNow() }
            self.nextFireAt = Date().addingTimeInterval(interval)
        }
        
        dsTimer = t
        t.resume()
    }

    // MARK: - Sync Operations
    
    @discardableResult
    public func syncNow() async -> Bool {
        status = .syncing
        NotificationCenter.default.post(name: .syncStatusDidChange, object: self)

        // Prefer external performer when provided (real app flow)
        if let performer = performer {
            let ok = await performWithRetry {
                await performer()
            }
            updateSyncStatus(success: ok, error: "performer failed after retries")
            return ok
        }

        do {
            try await performSync()
            updateSyncStatus(success: true)
            return true
        } catch {
            LOG(.error, "Sync failed: \(error)")
            updateSyncStatus(success: false, error: "\(error)")
            return false
        }
    }
    
    // MARK: - Private Methods
    
    private func performSync() async throws {
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
            try store.saveNoteTracking(
                NoteTracking(
                    noteID: note.id,
                    date: today,
                    previousWordCount: prev,
                    currentWordCount: current
                )
            )
        }

        let snapshot = try updateOrCreateDailySnapshot(
            for: today,
            totalWords: totalWords,
            modifiedCount: modifiedCount
        )
        
        try await postToBeeminder(snapshot: snapshot, date: today)
    }
    
    private func updateOrCreateDailySnapshot(for date: Date, totalWords: Int, modifiedCount: Int) throws -> DailySnapshot {
        var snapshot = try store.loadDailySnapshot(for: date) ?? DailySnapshot(
            date: date,
            totalWords: 0,
            notesModified: 0,
            topTags: [],
            syncStatus: "pending",
            lastUpdated: Date()
        )
        
        snapshot.totalWords += totalWords
        snapshot.notesModified = modifiedCount
        snapshot.lastUpdated = Date()
        try store.saveDailySnapshot(snapshot)
        
        return snapshot
    }
    
    private func postToBeeminder(snapshot: DailySnapshot, date: Date) async throws {
        let comment = "📝 \(snapshot.totalWords) words across \(snapshot.notesModified) notes\n\n🐻 via Bear → Beeminder"
        let dp = BeeminderDatapoint(
            value: snapshot.totalWords,
            comment: comment,
            requestID: "bear-sync-\(date)",
            timestamp: Date().timeIntervalSince1970
        )
        _ = try await beeminder.postDatapoint(dp, perform: false)
    }
    
    private func updateSyncStatus(success: Bool, error: String? = nil) {
        if success {
            status = .idle
            lastSyncAt = Date()
            consecutiveFailures = 0
        } else {
            status = .error(error ?? "Unknown error")
            consecutiveFailures += 1
        }
        NotificationCenter.default.post(name: .syncStatusDidChange, object: self)
    }
    
    /// Performs async operation with exponential backoff retry
    private func performWithRetry(_ operation: @escaping () async -> Bool) async -> Bool {
        for attempt in 0..<maxRetries {
            let success = await operation()
            if success { return true }
            
            // Don't wait after last attempt
            if attempt < maxRetries - 1 {
                let backoff = baseBackoffSeconds * pow(2.0, Double(attempt))
                LOG(.warning, "Sync attempt \(attempt + 1) failed, retrying in \(backoff)s")
                try? await Task.sleep(nanoseconds: UInt64(backoff * 1_000_000_000))
            }
        }
        LOG(.error, "Sync failed after \(maxRetries) attempts")
        return false
    }
}
