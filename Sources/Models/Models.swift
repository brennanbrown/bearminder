import Foundation

public struct DailySnapshot: Codable, Equatable {
    public let date: String // YYYY-MM-DD
    public var totalWords: Int
    public var notesModified: Int
    public var topTags: [String]
    public var syncStatus: String // pending, synced, error
    public var lastUpdated: Date

    public init(date: String, totalWords: Int, notesModified: Int, topTags: [String], syncStatus: String, lastUpdated: Date) {
        self.date = date
        self.totalWords = totalWords
        self.notesModified = notesModified
        self.topTags = topTags
        self.syncStatus = syncStatus
        self.lastUpdated = lastUpdated
    }
}

public struct NoteTracking: Codable, Equatable {
    public let noteID: String
    public let date: String // YYYY-MM-DD
    public var previousWordCount: Int
    public var currentWordCount: Int

    public init(noteID: String, date: String, previousWordCount: Int, currentWordCount: Int) {
        self.noteID = noteID
        self.date = date
        self.previousWordCount = previousWordCount
        self.currentWordCount = currentWordCount
    }
}

public struct BeeminderDatapoint: Codable, Equatable {
    public let value: Int
    public let comment: String
    public let requestID: String
    public let timestamp: TimeInterval

    public init(value: Int, comment: String, requestID: String, timestamp: TimeInterval) {
        self.value = value
        self.comment = comment
        self.requestID = requestID
        self.timestamp = timestamp
    }
}

public struct Settings: Codable, Equatable {
    public var beeminderUsername: String
    public var beeminderGoal: String
    public var trackTags: [String]? // nil => all notes
    public var syncFrequencyMinutes: Int // default 60

    public init(beeminderUsername: String, beeminderGoal: String, trackTags: [String]? = nil, syncFrequencyMinutes: Int = 60) {
        self.beeminderUsername = beeminderUsername
        self.beeminderGoal = beeminderGoal
        self.trackTags = trackTags
        self.syncFrequencyMinutes = syncFrequencyMinutes
    }
}

public struct BearNoteMeta: Codable, Equatable {
    public let id: String
    public let title: String
    public let wordCount: Int
    public let lastModified: Date
    public let creationDate: Date
    public let tags: [String]

    public init(id: String, title: String, wordCount: Int, lastModified: Date, creationDate: Date, tags: [String]) {
        self.id = id
        self.title = title
        self.wordCount = wordCount
        self.lastModified = lastModified
        self.creationDate = creationDate
        self.tags = tags
    }
}
