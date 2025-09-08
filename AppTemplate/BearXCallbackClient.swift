import AppKit
import Foundation
import Logging

/// Thin client to initiate Bear x-callback-url requests from the menubar app.
/// The app must register a custom URL scheme (see docs/AppSetup.md) and handle
/// callbacks in AppDelegate to receive results.
final class BearXCallbackClient {
    enum XCBError: Error { case invalidURL }

    func open(url: URL) throws {
        guard NSWorkspace.shared.open(url) else {
            throw XCBError.invalidURL
        }
    }

    /// Example: search notes modified today (placeholder – refine query as needed)
    /// - Parameters:
    ///   - token: Bear API token from Keychain
    ///   - xsuccess: your custom scheme success callback (e.g., bearminder://success)
    ///   - xerror: your custom scheme error callback (e.g., bearminder://error)
    func search(term: String, token: String, xsuccess: String, xerror: String) {
        var comps = URLComponents(string: "bear://x-callback-url/search")!
        comps.queryItems = [
            URLQueryItem(name: "term", value: term),
            URLQueryItem(name: "token", value: token),
            URLQueryItem(name: "x-success", value: xsuccess),
            URLQueryItem(name: "x-error", value: xerror)
        ]
        if let url = comps.url {
            LOG(.info, "Opening Bear search x-callback-url")
            _ = try? openAndLog(url)
        }
    }

    /// Example: open note (placeholder – typically used after search returns IDs)
    func openNote(id: String, token: String, xsuccess: String, xerror: String) {
        var comps = URLComponents(string: "bear://x-callback-url/open-note")!
        comps.queryItems = [
            URLQueryItem(name: "id", value: id),
            URLQueryItem(name: "token", value: token),
            URLQueryItem(name: "x-success", value: xsuccess),
            URLQueryItem(name: "x-error", value: xerror)
        ]
        if let url = comps.url {
            LOG(.info, "Opening Bear open-note x-callback-url for id=\(id)")
            _ = try? openAndLog(url)
        }
    }

    /// Attempt to fetch a note's metadata/text via x-callback. Bear's URL API varies by version; this
    /// uses open-note with best-effort flags to avoid UI and include the text so we can compute word counts.
    /// If the running Bear version ignores these flags, we'll still receive a callback with limited params.
    func fetchNote(id: String, token: String, xsuccess: String, xerror: String) {
        var comps = URLComponents(string: "bear://x-callback-url/open-note")!
        comps.queryItems = [
            URLQueryItem(name: "id", value: id),
            URLQueryItem(name: "token", value: token),
            URLQueryItem(name: "show_window", value: "no"),
            URLQueryItem(name: "new_window", value: "no"),
            URLQueryItem(name: "include_text", value: "yes"),
            URLQueryItem(name: "x-success", value: xsuccess),
            URLQueryItem(name: "x-error", value: xerror)
        ]
        if let url = comps.url {
            LOG(.info, "Opening Bear fetch-note x-callback-url for id=\(id)")
            _ = try? openAndLog(url)
        }
    }

    @discardableResult
    private func openAndLog(_ url: URL) throws -> Bool {
        LOG(.debug, "Open URL: \(url.absoluteString)")
        return NSWorkspace.shared.open(url)
    }
}
