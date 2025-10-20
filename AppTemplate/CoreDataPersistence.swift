import Foundation
import CoreData
import Models
import Logging
import Persistence

final class CoreDataPersistence: PersistenceType {
    private let container: NSPersistentContainer
    private let context: NSManagedObjectContext
    private let queueURL: URL

    init(storeURL: URL? = nil) {
        let model = CoreDataPersistence.makeModel()
        container = NSPersistentContainer(name: "BearMinder", managedObjectModel: model)
        if let url = storeURL {
            let desc = NSPersistentStoreDescription(url: url)
            // Enable lightweight migrations for automatic schema updates
            desc.shouldMigrateStoreAutomatically = true
            desc.shouldInferMappingModelAutomatically = true
            container.persistentStoreDescriptions = [desc]
        }
        container.loadPersistentStores { _, error in
            if let error = error {
                LOG(.error, "Core Data load error: \(error)")
            } else {
                LOG(.info, "Core Data store loaded successfully with lightweight migrations enabled")
            }
        }
        // Use a background context since sync runs off the main thread
        context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        // Offline queue JSON file
        let base = CoreDataPersistence.defaultStoreURL().deletingLastPathComponent()
        queueURL = base.appendingPathComponent("datapoint-queue.json")
        if !FileManager.default.fileExists(atPath: queueURL.path) {
            try? Data("[]".utf8).write(to: queueURL)
        }
    }

    // MARK: - PersistenceType
    func loadDailySnapshot(for date: String) throws -> DailySnapshot? {
        var result: DailySnapshot?
        try context.performAndWait {
            let req = NSFetchRequest<NSManagedObject>(entityName: "DailySnapshot")
            req.predicate = NSPredicate(format: "date == %@", date)
            req.fetchLimit = 1
            if let obj = try context.fetch(req).first {
                result = DailySnapshot(
                    date: date,
                    totalWords: obj.value(forKey: "totalWords") as? Int ?? 0,
                    notesModified: obj.value(forKey: "notesModified") as? Int ?? 0,
                    topTags: (obj.value(forKey: "topTags") as? String).flatMap { try? JSONDecoder().decode([String].self, from: Data($0.utf8)) } ?? [],
                    syncStatus: obj.value(forKey: "syncStatus") as? String ?? "pending",
                    lastUpdated: (obj.value(forKey: "lastUpdated") as? Date) ?? Date()
                )
            }
        }
        return result
    }

    func saveDailySnapshot(_ snapshot: DailySnapshot) throws {
        try context.performAndWait {
            let req = NSFetchRequest<NSManagedObject>(entityName: "DailySnapshot")
            req.predicate = NSPredicate(format: "date == %@", snapshot.date)
            let obj = try context.fetch(req).first ?? NSEntityDescription.insertNewObject(forEntityName: "DailySnapshot", into: context)
            obj.setValue(snapshot.date, forKey: "date")
            obj.setValue(snapshot.totalWords, forKey: "totalWords")
            obj.setValue(snapshot.notesModified, forKey: "notesModified")
            let tagsJSON = String(data: (try? JSONEncoder().encode(snapshot.topTags)) ?? Data("[]".utf8), encoding: .utf8)
            obj.setValue(tagsJSON, forKey: "topTags")
            obj.setValue(snapshot.syncStatus, forKey: "syncStatus")
            obj.setValue(snapshot.lastUpdated, forKey: "lastUpdated")
            try contextSave()
        }
    }

    func loadNoteTracking(noteID: String, date: String) throws -> NoteTracking? {
        var result: NoteTracking?
        try context.performAndWait {
            let req = NSFetchRequest<NSManagedObject>(entityName: "NoteTracking")
            req.predicate = NSPredicate(format: "noteID == %@ AND date == %@", noteID, date)
            req.fetchLimit = 1
            if let obj = try context.fetch(req).first {
                result = NoteTracking(
                    noteID: noteID,
                    date: date,
                    previousWordCount: obj.value(forKey: "previousWordCount") as? Int ?? 0,
                    currentWordCount: obj.value(forKey: "currentWordCount") as? Int ?? 0
                )
            }
        }
        return result
    }

    func saveNoteTracking(_ note: NoteTracking) throws {
        try context.performAndWait {
            let req = NSFetchRequest<NSManagedObject>(entityName: "NoteTracking")
            req.predicate = NSPredicate(format: "noteID == %@ AND date == %@", note.noteID, note.date)
            let obj = try context.fetch(req).first ?? NSEntityDescription.insertNewObject(forEntityName: "NoteTracking", into: context)
            obj.setValue(note.noteID, forKey: "noteID")
            obj.setValue(note.date, forKey: "date")
            obj.setValue(note.previousWordCount, forKey: "previousWordCount")
            obj.setValue(note.currentWordCount, forKey: "currentWordCount")
            try contextSave()
        }
    }

    private func contextSave() throws {
        if context.hasChanges {
            try context.save()
        }
    }

    // MARK: - Model
    static func makeModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        // DailySnapshot entity
        let daily = NSEntityDescription()
        daily.name = "DailySnapshot"
        daily.managedObjectClassName = "NSManagedObject"
        daily.properties = [
            attr("date", .stringAttributeType, isOptional: false, isIndexed: true),
            attr("totalWords", .integer64AttributeType),
            attr("notesModified", .integer64AttributeType),
            attr("topTags", .stringAttributeType), // JSON array
            attr("syncStatus", .stringAttributeType),
            attr("lastUpdated", .dateAttributeType)
        ]

        // NoteTracking entity (PK: noteID + date)
        let note = NSEntityDescription()
        note.name = "NoteTracking"
        note.managedObjectClassName = "NSManagedObject"
        let noteID = attr("noteID", .stringAttributeType, isOptional: false, isIndexed: true)
        let date = attr("date", .stringAttributeType, isOptional: false, isIndexed: true)
        note.properties = [
            noteID,
            date,
            attr("previousWordCount", .integer64AttributeType),
            attr("currentWordCount", .integer64AttributeType)
        ]
        note.uniquenessConstraints = [[noteID, date]]

        model.entities = [daily, note]
        return model
    }

    private static func attr(_ name: String, _ type: NSAttributeType, isOptional: Bool = true, isIndexed: Bool = false) -> NSAttributeDescription {
        let a = NSAttributeDescription()
        a.name = name
        a.attributeType = type
        a.isOptional = isOptional
        a.isIndexed = isIndexed
        return a
    }
    
        // MARK: - Queue Operations
    
    private func loadQueue() -> [BeeminderDatapoint] {
        guard let data = try? Data(contentsOf: queueURL) else { return [] }
        return (try? JSONDecoder().decode([BeeminderDatapoint].self, from: data)) ?? []
    }
    
    private func saveQueue(_ q: [BeeminderDatapoint]) {
        if let data = try? JSONEncoder().encode(q) {
            try? data.write(to: queueURL)
        }
    }
    
    func enqueueDatapoint(_ dp: BeeminderDatapoint) throws {
        var q = loadQueue()
        q.append(dp)
        // Optional bound to 50 items
        if q.count > 50 { q.removeFirst(q.count - 50) }
        saveQueue(q)
    }
    
    func dequeueAllDatapoints() throws -> [BeeminderDatapoint] {
        let q = loadQueue()
        saveQueue([])
        return q
    }
    
    func countQueuedDatapoints() throws -> Int { 
        loadQueue().count 
    }
}

// MARK: - Default Store URL
extension CoreDataPersistence {
    static func defaultStoreURL() -> URL {
        let fm = FileManager.default
        let appSupport = try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let dir = appSupport?.appendingPathComponent("BearMinder", isDirectory: true)
        if let dir = dir, !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return (dir ?? URL(fileURLWithPath: NSTemporaryDirectory())).appendingPathComponent("bearminder.sqlite")
    }
}
