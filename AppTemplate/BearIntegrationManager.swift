import Foundation
import AppKit
import Models
import Logging

/// Coordinates Bear x-callback-url flows and bridges results back as Models.BearNoteMeta
final class BearIntegrationManager {
    private let xcb = BearXCallbackClient()

    /// Initiates a Bear search for notes modified today and then fetches metadata for each note.
    /// Expects Bear to return a comma-separated list of IDs via `bearminder://success?op=search&ids=...`.
    /// For each ID, we request a follow-up fetch that returns note details and, if available, text for word count.
    func fetchNotesModifiedToday(token: String) async -> [BearNoteMeta] {
        let scheme = "bearminder"
        let searchSuccess = "\(scheme)://success?op=search"
        let searchError = "\(scheme)://error?op=search"

        // 1) Trigger a broad search; we will filter by modification date ourselves (see below)
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

            // Keep only notes modified "today" (UTC day boundary)
            let today = Self.todayString()
            let filteredSeeds = seedMetas.filter { meta in
                if let d = meta.modified { return Self.isSameDayUTC(d, todayString: today) }
                return false
            }
            LOG(.info, "Bear search filtered to today's notes count=\(filteredSeeds.count)")
            guard !filteredSeeds.isEmpty else { return [] }

            var results: [BearNoteMeta] = []
            results.reserveCapacity(filteredSeeds.count)

            // 3) For each seed, request note fetch and await its callback; fallback to seed metadata if fetch fails
            for seed in filteredSeeds {
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
            let body = params["text"] ?? params["note"]
            let wordCount = computeWordCount(from: body) ?? 0
            LOG(.debug, "Computed wordCount=\(wordCount) for id=\(id) title=\(title)")
            return BearNoteMeta(id: id, title: title, wordCount: wordCount, lastModified: modified, creationDate: created, tags: tags)
        } catch {
            LOG(.warning, "Bear fetch-note for id=\(id) failed: \(error)")
            return nil
        }
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
    private static func todayString() -> String {
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.timeZone = TimeZone(secondsFromGMT: 0)
        df.dateFormat = "yyyy-MM-dd"
        return df.string(from: Date())
    }

    private static func isSameDayUTC(_ date: Date, todayString: String) -> Bool {
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.timeZone = TimeZone(secondsFromGMT: 0)
        df.dateFormat = "yyyy-MM-dd"
        return df.string(from: date) == todayString
    }
}
