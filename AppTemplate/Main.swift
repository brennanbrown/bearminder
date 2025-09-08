import AppKit

@main
final class MainApp: NSObject {
    static func main() {
        // Explicit AppKit entry point to avoid scheme/executor ambiguity.
        // This ensures AppDelegate.applicationDidFinishLaunching is invoked.
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
