import Foundation
import Models
import Logging

public protocol PersistenceType {
    func loadDailySnapshot(for date: String) throws -> DailySnapshot?
    func saveDailySnapshot(_ snapshot: DailySnapshot) throws
    func loadNoteTracking(noteID: String, date: String) throws -> NoteTracking?
    func saveNoteTracking(_ note: NoteTracking) throws
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
}
