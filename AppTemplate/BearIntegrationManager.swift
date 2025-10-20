import Foundation
import AppKit
import Models
import Logging

// MARK: - Type Definitions

/// Represents a note's metadata during search and processing
private struct NoteSearchMetadata {
    // MARK: - Properties
    let id: String
    var title: String?
    var tags: [String]
    var modified: Date?
    var created: Date?
    
    // MARK: - Initialization
    init(id: String, title: String? = nil, tags: [String] = [], modified: Date? = nil, created: Date? = nil) {
        self.id = id
        self.title = title
        self.tags = tags
        self.modified = modified
        self.created = created
    }
}

/// Represents a note seed with its metadata
private struct NoteSeed {
    // MARK: - Properties
    let id: String
    let title: String?
    let tags: [String]
    let modified: Date?
    let created: Date?
}

/// Parameters for creating a note meta
private struct NoteMetaParameters {
    let id: String
    let fallbackTitle: String?
    let fallbackTags: [String]
    let fallbackModified: Date?
    let fallbackCreated: Date?
    let params: [String: String]
}

// MARK: - BearIntegrationManager

/// Coordinates Bear x-callback-url flows and bridges results back as Models.BearNoteMeta
final class BearIntegrationManager {
    // MARK: - Nested Types
    
    /// Parameters for creating a note meta
    private struct NoteMetaParameters {
        let id: String
        let fallbackTitle: String?
        let fallbackTags: [String]
        let fallbackModified: Date?
        let fallbackCreated: Date?
        let params: [String: String]
    }
    
    // MARK: - Properties
    
    private let xcb = BearXCallbackClient()
    
    /// If true, uses AppleScript instead of x-callback-url (avoids bringing Bear to foreground)
    var useAppleScriptMode: Bool {
        UserDefaults.standard.bool(forKey: "bear.useAppleScript")
    }

    // MARK: - Public Methods
    
    /// Initiates a Bear search for notes modified/created today (local day) and then fetches metadata for each note.
    /// Expects Bear to return a comma-separated list of IDs via `bearminder://success?op=search&ids=...`.
    /// For each ID, we request a follow-up fetch that returns note details and, if available, text for word count.
    /// If useAppleScriptMode is enabled, uses AppleScript instead to avoid bringing Bear to foreground.
    func fetchNotesModifiedToday(token: String) async -> [BearNoteMeta] {
        if useAppleScriptMode {
            return await fetchNotesViaAppleScript()
        }
        
        do {
            // 1) Perform initial search and get seed metadata
            let seedMetas = try await performInitialSearch(token: token)
            
            // 2) Filter for today's notes
            var workingSeeds = filterTodaysNotes(from: seedMetas)
            LOG(.info, "Bear search filtered to today's notes count=\(workingSeeds.count)")
            
            // 3) Fallback strategies if no notes found
            workingSeeds = await applyFallbackStrategies(
                currentSeeds: workingSeeds,
                token: token
            )
            
            // 4) Fetch full metadata for each note
            return await fetchFullMetadata(for: workingSeeds, token: token)
            
        } catch {
            LOG(.warning, "Bear search callback failed: \(error)")
            return []
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func performInitialSearch(token: String) async throws -> [NoteSearchMetadata] {
        let scheme = "bearminder"
        let searchSuccess = "\(scheme)://success?op=search"
        let searchError = "\(scheme)://error?op=search"
        
        xcb.search(
            term: "",
            token: token,
            xsuccess: searchSuccess,
            xerror: searchError
        )
        
        let params = try await waitForCallback { $0["op"] == "search" }
        return parseSearchResponse(params)
    }
    
    private func parseSearchResponse(_ params: [String: String]) -> [NoteSearchMetadata] {
        var seedMetas: [NoteSearchMetadata] = []
        
        if let ids = params["ids"], !ids.isEmpty {
            let idList = ids.split(separator: ",").map { String($0) }
            seedMetas = idList.map { NoteSearchMetadata(id: $0) }
        } else if let rawNotes = params["notes"], !rawNotes.isEmpty {
            seedMetas = parseNotesJSON(rawNotes)
        }
        
        return seedMetas
    }
    
    private func parseNotesJSON(_ rawNotes: String) -> [NoteSearchMetadata] {
        guard let decoded = rawNotes.removingPercentEncoding,
              let data = decoded.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        
        return array.compactMap { noteDict in
            let id = (noteDict["identifier"] as? String) ?? ""
            guard !id.isEmpty else { return nil }
            
            var meta = NoteSearchMetadata(
                id: id,
                title: noteDict["title"] as? String
            )
            
            if let tagsRaw = noteDict["tags"] as? String {
                meta.tags = parseTags(tagsRaw)
            }
            
            if let modifiedISO = noteDict["modificationDate"] as? String {
                meta.modified = parseDate(modifiedISO)
            }
            
            if let createdISO = noteDict["creationDate"] as? String {
                meta.created = parseDate(createdISO)
            }
            
            return meta
        }
    }
    
    private func filterTodaysNotes(from seeds: [NoteSearchMetadata]) -> [NoteSearchMetadata] {
        return seeds.filter { meta in
            if let modified = meta.modified, Self.isSameDayLocal(modified) { return true }
            if let created = meta.created, Self.isSameDayLocal(created) { return true }
            return false
        }
    }
    
    private func applyFallbackStrategies(currentSeeds: [NoteSearchMetadata], token: String) async -> [NoteSearchMetadata] {
        var seeds = currentSeeds
        
        // Fallback #1: Try Bear's native /today action
        if seeds.isEmpty {
            seeds = await fetchTodaySeedsViaTodayAction(token: token) ?? []
            if !seeds.isEmpty {
                LOG(.info, "Bear /today provided today's notes count=\(seeds.count)")
            }
        }
        
        // Fallback #2: Wait and retry search once (to allow iCloud sync)
        if seeds.isEmpty {
            seeds = await retrySearchWithDelay(token: token)
        }
        
        return seeds
    }
    
    private func retrySearchWithDelay(token: String) async -> [NoteSearchMetadata] {
        let scheme = "bearminder"
        let searchSuccess = "\(scheme)://success?op=search"
        let searchError = "\(scheme)://error?op=search"
        
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        xcb.search(term: "", token: token, xsuccess: searchSuccess, xerror: searchError)
        
        do {
            let retryParams = try await waitForCallback { $0["op"] == "search" }
            let seedMetas = parseSearchResponse(retryParams)
            return filterTodaysNotes(from: seedMetas)
        } catch {
            LOG(.warning, "Retry search failed: \(error)")
            return []
        }
    }
    
    private func fetchFullMetadata(for seeds: [NoteSearchMetadata], token: String) async -> [BearNoteMeta] {
        var results: [BearNoteMeta] = []
        
        for meta in seeds {
            if let noteMeta = await fetchNoteMeta(
                id: meta.id,
                title: meta.title,
                tags: meta.tags,
                modified: meta.modified,
                created: meta.created,
                token: token
            ) {
                results.append(noteMeta)
            } else {
                let fallbackDate = meta.modified ?? Date()
                results.append(
                    BearNoteMeta(
                        id: meta.id,
                        title: meta.title ?? "",
                        wordCount: 0,
                        lastModified: meta.modified ?? fallbackDate,
                        creationDate: meta.created ?? fallbackDate,
                        tags: meta.tags
                    )
                )
            }
        }
        
        LOG(.info, "Fetched \(results.count) notes with full metadata")
        return results
    }

    // MARK: - Private Methods
    
    private func fetchNoteMeta(
        id: String,
        title: String?,
        tags: [String],
        modified: Date?,
        created: Date?,
        token: String
    ) async -> BearNoteMeta? {
        let scheme = "bearminder"
        let success = "\(scheme)://success?op=note&id=\(id)"
        let error = "\(scheme)://error?op=note&id=\(id)"
        
        xcb.fetchNote(id: id, token: token, xsuccess: success, xerror: error)
        
        do {
            let params = try await waitForCallback { $0["op"] == "note" && $0["id"] == id }
            return await createNoteMeta(from: params, id: id, fallbackTitle: title, fallbackTags: tags, fallbackModified: modified, fallbackCreated: created)
        } catch {
            LOG(.warning, "Bear fetch-note for id=\(id) failed: \(error)")
            return nil
        }
    }
    
    private func createNoteMeta(
        from params: [String: String],
        id: String,
        fallbackTitle: String?,
        fallbackTags: [String],
        fallbackModified: Date?,
        fallbackCreated: Date?
    ) async -> BearNoteMeta {
        let title = params["title"] ?? fallbackTitle ?? ""
        let tags = parseTags(params["tags"]) + fallbackTags
        let modified = parseDate(params["modificationDate"]) ?? fallbackModified ?? Date()
        let created = parseDate(params["creationDate"]) ?? fallbackCreated ?? modified
        
        // Get note body and compute word count
        var body = params["text"] ?? params["note"]
        var wordCount = computeWordCount(from: body) ?? 0
        
        // Fallback to AppleScript if needed
        if (body == nil || body?.isEmpty == true) || wordCount == 0 {
            if let fallback = fetchBodyViaAppleScript(noteID: id), !fallback.isEmpty {
                body = fallback
                wordCount = computeWordCount(from: body) ?? 0
                LOG(.info, "AppleScript fallback provided body for id=\(id.prefix(8)) (wc=\(wordCount))")
            }
        }
        
        LOG(.debug, "Computed wordCount=\(wordCount) for id=\(id) title=\(title)")
        return BearNoteMeta(
            id: id,
            title: title,
            wordCount: wordCount,
            lastModified: modified,
            creationDate: created,
            tags: tags
        )
    }

    /// Best-effort AppleScript fallback. Requires Bear's AppleScript support.
    /// Returns plain text for the note if available.
    private func fetchBodyViaAppleScript(noteID: String) -> String? {
        let scriptSource = """
        try
            tell application \"Bear\"
                set theText to ""
                try
                    set theText to text of note id \"%@\"
                end try
            end tell
            return theText
        on error
            return ""
        end try
        """
        let source = String(format: scriptSource, noteID)
        if let script = NSAppleScript(source: source) {
            var error: NSDictionary?
            if let output = script.executeAndReturnError(&error).stringValue, !output.isEmpty {
                return output
            } else if let error = error {
                LOG(.warning, "AppleScript fallback failed: \(error)")
            }
        }
        return nil
    }

    private func waitForCallback(matcher: @escaping ([String: String]) -> Bool) async throws -> [String: String] {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[String: String], Error>) in
            var token: NSObjectProtocol?
            var timeoutTask: Task<Void, Never>?
            var isResumed = false
            
            token = NotificationCenter.default.addObserver(forName: .bearCallbackReceived, object: nil, queue: .main) { note in
                guard let result = note.userInfo?["result"] as? BearCallbackCoordinator.Result else { return }
                let params = result.params
                guard matcher(params) else { return }
                guard !isResumed else { return }
                isResumed = true
                if let t = token { NotificationCenter.default.removeObserver(t) }
                timeoutTask?.cancel()
                continuation.resume(returning: params)
            }
            
            // Timeout after 30 seconds
            timeoutTask = Task {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                guard !isResumed else { return }
                isResumed = true
                if let t = token { NotificationCenter.default.removeObserver(t) }
                continuation.resume(throwing: NSError(domain: "BearIntegration", code: -1, userInfo: [NSLocalizedDescriptionKey: "Bear callback timeout"]))
            }
        }
    }

    // MARK: - Parsing helpers
    private func parseTags(_ raw: String?) -> [String] {
        guard let raw = raw, !raw.isEmpty else { return [] }
        return raw.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    private func parseDate(_ iso: String?) -> Date? {
        guard let iso = iso, !iso.isEmpty else { return nil }
        let df = ISO8601DateFormatter()
        return df.date(from: iso)
    }

    private func computeWordCount(from text: String?) -> Int? {
        guard let text = text else { return nil }
        // Simple tokenization on whitespace/newlines
        let tokens = text.split { $0.isWhitespace || $0.isNewline }
        return tokens.count
    }

    // MARK: - Date helpers (UTC day compare)
    private static func isSameDayLocal(_ date: Date) -> Bool {
        let cal = Calendar.current
        return cal.isDateInToday(date)
    }
    
    // MARK: - AppleScript Mode (doesn't bring Bear to foreground)
    
    /// Fetches today's notes via AppleScript - doesn't bring Bear to foreground
    private func fetchNotesViaAppleScript() async -> [BearNoteMeta] {
        return await Task.detached {
            let scriptSource = """
            tell application "Bear"
                set notesList to notes
                set todayNotes to {}
                set currentDate to current date
                set currentYear to year of currentDate
                set currentMonth to month of currentDate as integer
                set currentDay to day of currentDate
                
                repeat with aNote in notesList
                    set modDate to modification date of aNote
                    set modYear to year of modDate
                    set modMonth to month of modDate as integer
                    set modDay to day of modDate
                    
                    -- Check if modified today (local time)
                    if modYear = currentYear and modMonth = currentMonth and modDay = currentDay then
                        set noteId to id of aNote
                        set noteTitle to title of aNote
                        set noteText to text of aNote
                        set noteTags to tags of aNote
                        
                        -- Build a simple record
                        set noteRecord to {noteId:noteId, noteTitle:noteTitle, noteText:noteText, noteTags:noteTags, modDate:modDate}
                        set end of todayNotes to noteRecord
                    end if
                end repeat
                
                return todayNotes
            end tell
            """
            
            guard let script = NSAppleScript(source: scriptSource) else {
                LOG(.error, "Failed to create AppleScript")
                return []
            }
            
            var error: NSDictionary?
            let result = script.executeAndReturnError(&error)
            
            if let error = error {
                LOG(.error, "AppleScript execution failed: \(error)")
                return []
            }
            
            // Parse the AppleScript result
            return self.parseAppleScriptResult(result)
        }.value
    }
    
    private func parseAppleScriptResult(_ result: NSAppleEventDescriptor) -> [BearNoteMeta] {
        var notes: [BearNoteMeta] = []
        
        // result is a list of records
        for i in 1...result.numberOfItems {
            guard let record = result.atIndex(i) else { continue }
            
            // Extract fields from the record
            guard let idDesc = record.forKeyword(AEKeyword(fourCharCode("noteId"))),
                  let titleDesc = record.forKeyword(AEKeyword(fourCharCode("noteTitl"))),
                  let textDesc = record.forKeyword(AEKeyword(fourCharCode("noteTxt"))),
                  let modDesc = record.forKeyword(AEKeyword(fourCharCode("modDate"))),
                  let id = idDesc.stringValue,
                  let title = titleDesc.stringValue,
                  let text = textDesc.stringValue else {
                continue
            }
            
            // Parse tags (may be missing)
            var tags: [String] = []
            if let tagsDesc = record.forKeyword(AEKeyword(fourCharCode("noteTags"))),
               let tagsString = tagsDesc.stringValue {
                tags = tagsString.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
            }
            
            // Compute word count
            let wordCount = computeWordCount(from: text) ?? 0
            
            // Parse modification date
            let modDate: Date
            if let dateNum = modDesc.dateValue {
                modDate = dateNum
            } else {
                modDate = Date()
            }
            
            let note = BearNoteMeta(id: id, title: title, wordCount: wordCount, lastModified: modDate, creationDate: modDate, tags: tags)
            notes.append(note)
        }
        
        LOG(.info, "AppleScript mode fetched \(notes.count) notes modified today")
        return notes
    }
    
    private func fourCharCode(_ string: String) -> FourCharCode {
        var result: FourCharCode = 0
        for char in string.utf8 {
            result = (result << 8) + FourCharCode(char)
        }
        return result
    }

    // MARK: - Note Seed Model
    
    private struct NoteSeed {
        let id: String
        let title: String?
        let tags: [String]
        let modified: Date?
        let created: Date?
    }
    
    // MARK: - Today Action Methods
    
    private func fetchTodaySeedsViaTodayAction(token: String) async -> [NoteSeed]? {
        let scheme = "bearminder"
        let success = "\(scheme)://success?op=today"
        let error = "\(scheme)://error?op=today"
        var comps = URLComponents(string: "bear://x-callback-url/today")!
        comps.queryItems = [
            URLQueryItem(name: "token", value: token),
            URLQueryItem(name: "x-success", value: success),
            URLQueryItem(name: "x-error", value: error)
        ]
        
        guard let url = comps.url else { return nil }
        LOG(.debug, "Open URL: \(url.absoluteString)")
        _ = try? xcb.open(url: url)
        
        do {
            let params = try await waitForCallback { $0["op"] == "today" }
            return try await parseTodayResponse(params)
        } catch {
            LOG(.warning, "Bear /today callback failed: \(error)")
            return nil
        }
    }
    
    private func parseTodayResponse(_ params: [String: String]) async throws -> [NoteSeed] {
        guard let rawNotes = params["notes"], 
              !rawNotes.isEmpty,
              let decoded = rawNotes.removingPercentEncoding,
              let data = decoded.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        
        return array.compactMap { noteDict in
            guard let id = noteDict["identifier"] as? String, 
                  !id.isEmpty else { 
                return nil 
            }
            
            let title = noteDict["title"] as? String
            let tagsRaw = noteDict["tags"] as? String
            let tags = parseTags(tagsRaw)
            let modified = parseDate(noteDict["modificationDate"] as? String)
            let created = parseDate(noteDict["creationDate"] as? String)
            
            return NoteSeed(
                id: id, 
                title: title, 
                tags: tags, 
                modified: modified, 
                created: created
            )
        }
    }
}
