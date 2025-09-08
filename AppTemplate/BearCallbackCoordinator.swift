import Foundation
import Logging

/// Parses incoming x-callback-url responses from Bear and publishes structured results.
/// Integrate with this coordinator from AppDelegate URL handler.
final class BearCallbackCoordinator {
    enum CallbackKind { case success, error }

    struct Result {
        let kind: CallbackKind
        let path: String
        let params: [String: String]
    }

    /// Handle an incoming URL, parse query parameters, and post a notification.
    /// - Returns: Parsed `Result` for immediate handling if needed.
    @discardableResult
    func handle(url: URL) -> Result {
        let kind: CallbackKind = url.host == "success" ? .success : .error
        let params = Self.parseQuery(url: url)
        let res = Result(kind: kind, path: url.path, params: params)
        LOG(.info, "Bear callback kind=\(kind == .success ? "success" : "error") params=\(params)")
        NotificationCenter.default.post(name: .bearCallbackReceived, object: self, userInfo: ["result": res])
        return res
    }

    private static func parseQuery(url: URL) -> [String: String] {
        var dict: [String: String] = [:]
        guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return dict }
        for item in comps.queryItems ?? [] {
            dict[item.name] = item.value ?? ""
        }
        return dict
    }
}

extension Notification.Name {
    static let bearCallbackReceived = Notification.Name("BearCallbackReceivedNotification")
}
