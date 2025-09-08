# Menubar App Setup (Xcode)

This guide wires the existing Swift Package core into a macOS AppKit menubar app.

## 1) Create the Xcode project
1. Open Xcode → File → New → Project…
2. Choose "App" under macOS → Next.
3. Product Name: `BearMinder`
4. Team: your Apple ID team
5. Organization Identifier: `com.yourdomain`
6. Interface: Storyboard (we'll replace entry)
7. Language: Swift
8. Uncheck "Use Core Data" (we will add later)
9. Create in the repository root: `bearminder/Apps/BearMinder/` (recommended)

## 2) Configure as a menubar-only app
1. Select the project → Targets → `BearMinder` → Info.
2. Add a new key in `Info.plist`:
   - `Application is agent (UIElement)` = `YES` (LSUIElement = 1). Hides Dock icon and app switcher entry.
3. Delete the default storyboard reference if present (or leave; we won’t use it).

### Register a custom URL scheme (for Bear x-callback-url)
Bear returns to the caller via `x-success`/`x-error` URLs. Register a custom URL scheme so your app can receive callbacks:

1. Targets → `BearMinder` → Info → URL Types → +
2. Identifier: `com.yourdomain.bearminder.url`
3. URL Schemes: `bearminder` (choose your own; remember it)
4. Role: Editor

In code, implement URL handling to process callbacks (e.g., in `AppDelegate` using NSAppleEventManager or NSApplication delegate methods) and pass data to a `BearXCallbackClient`.

## 3) Add the core Swift Package
1. Project → `BearMinder` → Package Dependencies → +
2. Click "Add Local…" and select the repository root folder `bearminder` (where `Package.swift` lives).
3. Add products:
   - `BearMinderCore` (this exposes all needed targets)

## 4) Add App source files
1. In Finder, locate templates under `AppTemplate/`:
   - `AppTemplate/AppDelegate.swift`
   - `AppTemplate/StatusItemController.swift`
   - `AppTemplate/SettingsWindowController.swift`
2. Drag these three files into the Xcode app target’s source group ("Copy if needed").
3. Remove the default `AppDelegate.swift`/Scene/Storyboard files Xcode created, if any.

## 5) Set the entry point
1. Ensure `@main` exists on `AppDelegate` in the imported template.
2. Build target → General → Frameworks, Libraries, and Embedded Content: ensure the Swift package target products are linked (`Models`, `Logging`, `KeychainSupport`, `BeeminderClient`, `BearClient`, `Persistence`, `SyncManager`). If you added the umbrella product `BearMinderCore`, Xcode links the component targets automatically.

## 6) Keychain usage
- The `AppTemplate/AppDelegate.swift` includes a minimal placeholder `KeychainHelper`. Replace these calls with the real implementations from the `KeychainSupport` target when you wire the app to actual settings inputs.

## 7) User defaults keys used by the template
- `beeminder.username` (String)
- `beeminder.goal` (String)
- `sync.frequency.minutes` (Int, default 60)

The Settings window template writes these values; `AppDelegate` reads them at launch.

## 8) Start at Login (later)
- Use `SMAppService` in the app target to register as a login item. This requires adding a Helper target if you want a separate login helper, or using the unified Login Item API on macOS 13+.
- This is post-MVP and can be added once the app runs.

## 9) Run
1. Select the `BearMinder` scheme.
2. Build & Run. You should see a 🐻 icon in the menu bar.
3. Use the menu to open Settings, adjust values, and invoke "Sync Now" (dry-run in current core).

## Notes
- The core currently performs a dry-run Beeminder POST and uses a stubbed Bear client that returns no notes. Once the Bear integration is implemented, the menubar app will reflect real word counts.
- To show a green/yellow/red dot status in the icon, update `StatusItemController.install()` to set a templated image and draw a status badge. This is a small UI follow-up.

## Bear x-callback-url integration (overview)
- Launch Bear queries using URLs like:
  - `bear://x-callback-url/search?term=...&token=...&x-success=bearminder://success&x-error=bearminder://error`
- Implement a `BearXCallbackClient` in the app target that:
  1) Opens the URL with `NSWorkspace.shared.open(_:)`.
  2) Waits for the callback to arrive via your URL scheme.
  3) Parses results (Bear provides note identifiers/metadata) and then, if needed, fetches per-note content for word counting.
- Consider a background-friendly UX: schedule syncs when user is idle to minimize focus disruptions; add retry/backoff.
