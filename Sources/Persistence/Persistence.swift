import Foundation
import Models
import Logging

public protocol PersistenceType {
    func loadDailySnapshot(for date: String) throws -> DailySnapshot?
    func saveDailySnapshot(_ snapshot: DailySnapshot) throws
    func loadNoteTracking(noteID: String, date: String) throws -> NoteTracking?
    func saveNoteTracking(_ note: NoteTracking) throws
    // Offline queue for Beeminder datapoints
    func enqueueDatapoint(_ dp: BeeminderDatapoint) throws
    func dequeueAllDatapoints() throws -> [BeeminderDatapoint]
    func countQueuedDatapoints() throws -> Int
}

// Minimal in-memory placeholder implementation to enable compilation.
public final class InMemoryPersistence: PersistenceType {
    private var snapshots: [String: DailySnapshot] = [:] // key: date
    private var noteTracking: [String: NoteTracking] = [:] // key: noteID|date

    public init() {}

    public func loadDailySnapshot(for date: String) throws -> DailySnapshot? {
        snapshots[date]
    }

    public func saveDailySnapshot(_ snapshot: DailySnapshot) throws {
        snapshots[snapshot.date] = snapshot
        LOG(.debug, "Saved DailySnapshot for date=\(snapshot.date), total=\(snapshot.totalWords)")
    }

    public func loadNoteTracking(noteID: String, date: String) throws -> NoteTracking? {
        noteTracking["\(noteID)|\(date)"]
    }

    public func saveNoteTracking(_ note: NoteTracking) throws {
        noteTracking["\(note.noteID)|\(note.date)"] = note
        LOG(.debug, "Saved NoteTracking for id=\(note.noteID) date=\(note.date) current=\(note.currentWordCount)")
    }

    // MARK: - Offline queue (in-memory no-op)
    private var queue: [BeeminderDatapoint] { get { _queue } set { _queue = newValue } }
    private static var _queueStore: [BeeminderDatapoint] = []
    private var _queue: [BeeminderDatapoint] {
        get { Self._queueStore }
        set { Self._queueStore = newValue }
    }

    public func enqueueDatapoint(_ dp: BeeminderDatapoint) throws {
        var q = queue
        q.append(dp)
        queue = q
    }

    public func dequeueAllDatapoints() throws -> [BeeminderDatapoint] {
        let q = queue
        queue = []
        return q
    }

    public func countQueuedDatapoints() throws -> Int { queue.count }
}
