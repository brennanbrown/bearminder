import AppKit
import Logging

extension AppDelegate {
    // MARK: - URL Handling
    
    /// Call from applicationDidFinishLaunching to start listening for URL callbacks
    func registerURLHandler() {
        let manager = NSAppleEventManager.shared()
        manager.setEventHandler(
            self,
            andSelector: #selector(handleGetURLEvent(event:replyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
        LOG(.info, "Registered URL handler for kAEGetURL events")
    }
    
    /// Handles URL events received by the application
    /// - Parameters:
    ///   - event: The Apple event containing the URL
    ///   - replyEvent: The reply event (unused)
    @objc
    func handleGetURLEvent(
        event: NSAppleEventDescriptor,
        replyEvent: NSAppleEventDescriptor
    ) {
        guard let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: urlString) else {
            LOG(.warning, "Received kAEGetURL with no/invalid URL")
            return
        }
        // Example: bearminder://success?ids=...
        LOG(.info, "Received URL callback: \(url.absoluteString)")
        _ = callbackCoordinator.handle(url: url)
    }
}
