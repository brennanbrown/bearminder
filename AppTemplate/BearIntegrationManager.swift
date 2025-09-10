import Foundation
import AppKit
import Models
import Logging

/// Coordinates Bear x-callback-url flows and bridges results back as Models.BearNoteMeta
final class BearIntegrationManager {
    private let xcb = BearXCallbackClient()

    /// Initiates a Bear search for notes modified/created today (local day) and then fetches metadata for each note.
    /// Expects Bear to return a comma-separated list of IDs via `bearminder://success?op=search&ids=...`.
    /// For each ID, we request a follow-up fetch that returns note details and, if available, text for word count.
    func fetchNotesModifiedToday(token: String) async -> [BearNoteMeta] {
        let scheme = "bearminder"
        let searchSuccess = "\(scheme)://success?op=search"
        let searchError = "\(scheme)://error?op=search"

        // 1) Trigger a broad search; we will filter by local-day created/modified (see below)
        xcb.search(term: "", token: token, xsuccess: searchSuccess, xerror: searchError)

        do {
            // 2) Await search results; Bear returns a JSON-encoded notes array in `notes`
            let params = try await waitForCallback { $0["op"] == "search" }

            // Prefer `ids`, but support `notes` JSON (observed on your setup)
            var seedMetas: [(id: String, title: String?, tags: [String], modified: Date?, created: Date?)] = []
            if let ids = params["ids"], !ids.isEmpty {
                let idList = ids.split(separator: ",").map { String($0) }
                seedMetas = idList.map { ($0, nil, [], nil, nil) }
            } else if let rawNotes = params["notes"], !rawNotes.isEmpty {
                if let decoded = rawNotes.removingPercentEncoding,
                   let data = decoded.data(using: .utf8),
                   let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                    for n in array {
                        let id = (n["identifier"] as? String) ?? ""
                        guard !id.isEmpty else { continue }
                        let title = n["title"] as? String
                        let tagsRaw = n["tags"] as? String
                        let tags = parseTags(tagsRaw)
                        let modifiedISO = (n["modificationDate"] as? String)
                        let modified = parseDate(modifiedISO)
                        let createdISO = (n["creationDate"] as? String)
                        let created = parseDate(createdISO)
                        seedMetas.append((id, title, tags, modified, created))
                    }
                }
            }

            // Keep only notes that were modified or created "today" (LOCAL day boundary).
            // This better matches user expectations and mobile-to-Mac iCloud sync timing.
            let filteredSeeds = seedMetas.filter { meta in
                if let d = meta.modified, Self.isSameDayLocal(d) { return true }
                if let c = meta.created, Self.isSameDayLocal(c) { return true }
                return false
            }
            LOG(.info, "Bear search filtered to today's notes count=\(filteredSeeds.count)")
            var workingSeeds = filteredSeeds

            // Fallback #1: if empty, try Bear's native /today action which returns its notion of "today"
            if workingSeeds.isEmpty {
                if let todaySeeds = await fetchTodaySeedsViaTodayAction(token: token) {
                    workingSeeds = todaySeeds
                    LOG(.info, "Bear /today provided today's notes count=\(workingSeeds.count)")
                }
            }

            // Fallback #2: if still empty, wait briefly and retry search once (to allow iCloud sync)
            if workingSeeds.isEmpty {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                xcb.search(term: "", token: token, xsuccess: searchSuccess, xerror: searchError)
                let retryParams = try? await waitForCallback { $0["op"] == "search" }
                if let rawNotes = retryParams?["notes"], !rawNotes.isEmpty,
                   let decoded = rawNotes.removingPercentEncoding,
                   let data = decoded.data(using: .utf8),
                   let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                    var seeds: [(id: String, title: String?, tags: [String], modified: Date?, created: Date?)] = []
                    for n in array {
                        let id = (n["identifier"] as? String) ?? ""
                        guard !id.isEmpty else { continue }
                        let title = n["title"] as? String
                        let tagsRaw = n["tags"] as? String
                        let tags = parseTags(tagsRaw)
                        let modifiedISO = (n["modificationDate"] as? String)
                        let modified = parseDate(modifiedISO)
                        let createdISO = (n["creationDate"] as? String)
                        let created = parseDate(createdISO)
                        if (modified != nil && Self.isSameDayLocal(modified!)) || (created != nil && Self.isSameDayLocal(created!)) {
                            seeds.append((id, title, tags, modified, created))
                        }
                    }
                    workingSeeds = seeds
                    LOG(.info, "Retry search filtered to today's notes count=\(workingSeeds.count)")
                }
            }

            guard !workingSeeds.isEmpty else { return [] }

            var results: [BearNoteMeta] = []
            results.reserveCapacity(filteredSeeds.count)

            // 3) For each seed, request note fetch and await its callback; fallback to seed metadata if fetch fails
            for seed in workingSeeds {
                if let meta = await fetchNoteMeta(id: seed.id, token: token, scheme: scheme, seedCreated: seed.created) {
                    results.append(meta)
                } else {
                    results.append(BearNoteMeta(id: seed.id,
                                               title: seed.title ?? "",
                                               wordCount: 0,
                                               lastModified: seed.modified ?? Date(),
                                               creationDate: seed.created ?? (seed.modified ?? Date()),
                                               tags: seed.tags))
                }
            }
            return results
        } catch {
            LOG(.warning, "Bear search callback failed: \(error)")
            return []
        }
    }

    private func fetchNoteMeta(id: String, token: String, scheme: String, seedCreated: Date?) async -> BearNoteMeta? {
        let success = "\(scheme)://success?op=note&id=\(id)"
        let error = "\(scheme)://error?op=note&id=\(id)"
        xcb.fetchNote(id: id, token: token, xsuccess: success, xerror: error)

        do {
            // Match both op=note and id
            let params = try await waitForCallback { p in p["op"] == "note" && p["id"] == id }
            // Expected params (best-effort): id, title, tags (comma-separated), modified (ISO8601), text|note
            let title = params["title"] ?? ""
            let tags = parseTags(params["tags"]) 
            let modified = parseDate(params["modificationDate"]) ?? Date()
            let created = parseDate(params["creationDate"]) ?? seedCreated ?? modified
            // Bear may return body under "text" or "note" depending on action/version
            var body = params["text"] ?? params["note"]
            var wordCount = computeWordCount(from: body) ?? 0
            // Optional AppleScript fallback if body is missing or empty
            if (body == nil || body?.isEmpty == true) || wordCount == 0 {
                if let fallback = fetchBodyViaAppleScript(noteID: id), !fallback.isEmpty {
                    body = fallback
                    wordCount = computeWordCount(from: body) ?? 0
                    LOG(.info, "AppleScript fallback provided body for id=\(id.prefix(8)) (wc=\(wordCount))")
                }
            }
            LOG(.debug, "Computed wordCount=\(wordCount) for id=\(id) title=\(title)")
            return BearNoteMeta(id: id, title: title, wordCount: wordCount, lastModified: modified, creationDate: created, tags: tags)
        } catch {
            LOG(.warning, "Bear fetch-note for id=\(id) failed: \(error)")
            return nil
        }
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
            token = NotificationCenter.default.addObserver(forName: .bearCallbackReceived, object: nil, queue: .main) { note in
                guard let result = note.userInfo?["result"] as? BearCallbackCoordinator.Result else { return }
                let params = result.params
                guard matcher(params) else { return }
                if let t = token { NotificationCenter.default.removeObserver(t) }
                continuation.resume(returning: params)
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

    private func fetchTodaySeedsViaTodayAction(token: String) async -> [(id: String, title: String?, tags: [String], modified: Date?, created: Date?)]? {
        let scheme = "bearminder"
        let success = "\(scheme)://success?op=today"
        let error = "\(scheme)://error?op=today"
        var comps = URLComponents(string: "bear://x-callback-url/today")!
        comps.queryItems = [
            URLQueryItem(name: "token", value: token),
            URLQueryItem(name: "x-success", value: success),
            URLQueryItem(name: "x-error", value: error)
        ]
        if let url = comps.url { _ = try? xcb.openAndLog(url) }
        do {
            let params = try await waitForCallback { $0["op"] == "today" }
            if let rawNotes = params["notes"], !rawNotes.isEmpty,
               let decoded = rawNotes.removingPercentEncoding,
               let data = decoded.data(using: .utf8),
               let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                var seeds: [(id: String, title: String?, tags: [String], modified: Date?, created: Date?)] = []
                for n in array {
                    let id = (n["identifier"] as? String) ?? ""
                    guard !id.isEmpty else { continue }
                    let title = n["title"] as? String
                    let tagsRaw = n["tags"] as? String
                    let tags = parseTags(tagsRaw)
                    let modified = parseDate(n["modificationDate"] as? String)
                    let created = parseDate(n["creationDate"] as? String)
                    seeds.append((id, title, tags, modified, created))
                }
                return seeds
            }
        } catch {
            LOG(.warning, "Bear /today callback failed: \(error)")
        }
        return nil
    }
}
