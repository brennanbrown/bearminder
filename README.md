# BearMinder — Bear → Beeminder word tracker (macOS menubar)

BearMinder is a tiny macOS menubar app that totals the words you wrote in Bear today and posts them to your Beeminder goal. It stays out of the way, runs on-demand or hourly, and keeps your tokens securely in the Keychain.


## Quick Start (non‑technical users)

1) Install and open the app
- Build from source (ask a friend) or download a signed build when available.
- Launch the app. A 🐻 icon appears in your macOS menu bar.

2) Open Settings
- Click 🐻 → Settings.
- Fill in:
  - Beeminder Username
  - Beeminder API Token (from https://www.beeminder.com/api/v1/auth_token.json)
  - Beeminder Goal (for example: `writing`)
  - Bear API Token (in Bear: Help → Advanced → API Token → Copy)
- Save. On first access, macOS may ask you to allow Keychain access. Choose "Always Allow" so you aren’t asked again on each launch.

3) Run your first sync
- Click 🐻 → Sync Now.
- If you wrote today in Bear, BearMinder will post the number of new words written today to Beeminder.
- Your datapoint’s comment shows a short summary (words, notes, tags) on two lines.

4) Daily use
- Just write in Bear—nothing else to do.
- Click 🐻 → Sync Now anytime. (Automatic hourly sync will be added soon.)
- If you didn’t write since the last sync, BearMinder won’t post a zero.

Troubleshooting
- No 🐻 in the menu bar: make sure the app launched. If needed, quit and relaunch.
- It asks for Keychain permissions every launch: after saving tokens, macOS may prompt once; choose "Always Allow". If it still prompts, open Keychain Access, locate items with Service "beeminder" and "bear" (Account: "token"), and add BearMinder to their Access Control.
- No words posted despite writing: click Sync Now and check the log in Xcode (or share it with a developer). BearMinder counts only words written today (UTC) across notes that were modified today.


## What gets posted to Beeminder
- Value = today’s delta only (idempotent): words added today since yesterday’s final counts.
- Comment = a short two‑line summary:
  - "📝 {today_words}w | 📚 {notes_modified} notes | 🏷️ {unique_tags} tags"
  - blank line + "🐻 via Bear → Beeminder"


---

# Developer Guide

## Project Structure
- `Apps/BearMinder/` — XcodeGen app project (AppKit menubar app)
- `AppTemplate/` — App layer (AppDelegate, StatusItemController, Settings window, Bear integration glue)
- `Sources/` — Swift Package modules
  - `Models/` — data models (snapshots, tracking, settings, datapoints, BearNoteMeta)
  - `Logging/` — simple logging helper
  - `KeychainSupport/` — Keychain read/write wrappers
  - `BeeminderClient/` — Beeminder datapoint POST client
  - `BearClient/` — placeholder client and types
  - `Persistence/` — persistence protocol + Core Data impl (app target uses it)
  - `SyncManager/` — polling/trigger logic (in progress)
- `docs/` — spec and setup notes

## Build & Run
1) Generate the Xcode project for the app (XcodeGen):
```
cd Apps/BearMinder
xcodegen generate
open BearMinder.xcodeproj
```
2) Select the `BearMinder` scheme → Destination `My Mac` → Build & Run.

Command‑line build (no Xcode GUI):
```
# Build into ./build without code signing
xcodebuild -project Apps/BearMinder/BearMinder.xcodeproj \
  -scheme BearMinder -configuration Debug \
  -derivedDataPath build CODE_SIGNING_ALLOWED=NO build

# Launch the built app
open build/Build/Products/Debug/BearMinder.app
```

## Local credentials (optional for dev)
- Create `local/credentials.json` (gitignored) using `local.sample/credentials.json`:
```
{
  "beeminderUsername": "yourname",
  "beeminderGoal": "writing",
  "beeminderToken": "...",
  "bearToken": "..."
}
```
- On launch, `AppTemplate/LocalConfigLoader.swift` seeds `UserDefaults` + Keychain if empty.

## How today’s words are computed
- `AppTemplate/BearIntegrationManager.swift`
  - Triggers a Bear `search` x‑callback with an empty term (broad), Bear returns a JSON `notes` array.
  - Filters to notes whose `modificationDate` is today (UTC).
  - For each note, calls `open-note` to fetch metadata and body text.
  - Counts words from the `text` or `note` callback param.
- `AppTemplate/AppDelegate.performRealSyncNow()`
  - Baseline = yesterday’s end‑of‑day count per note (UTC); if none, baseline = 0.
  - Today’s delta = sum(max(0, current - baseline)) for all notes modified today.
  - Stores `NoteTracking` for today with `previousWordCount = baseline`, `currentWordCount = current`.
  - Posts only today’s delta to Beeminder, skipping if delta is 0.

## Key technical details
- Menu bar icon/title: `AppTemplate/StatusItemController.swift` (emoji title fallback for reliability)
- App entrypoint: explicit `@main` class in `AppTemplate/Main.swift` (avoids lifecycle ambiguity)
- URL callbacks: `AppTemplate/AppDelegate+URLHandling.swift` registers for `kAEGetURL` and forwards to `BearCallbackCoordinator`.
- Token storage: `Sources/KeychainSupport/KeychainSupport.swift` writes with `kSecAttrAccessibleAfterFirstUnlock` to reduce repeated prompts. If Keychain prompts recur, re‑save tokens in Settings and choose "Always Allow".
- Beeminder POST: `Sources/BeeminderClient/BeeminderClient.swift` builds an `application/x-www-form-urlencoded` body using `URLComponents.percentEncodedQuery`, so newlines render properly.

## Roadmap (short)
- Hourly background sync (`SyncManager`) and last‑sync status in menu.
- Optional tag filter UI and logic.
- Graceful error toasts and queueing for offline posts.
- Remove launch alert and trim logs for production.

## Contributing
- Issues and PRs welcome. Please:
  - Keep UI tiny and unobtrusive.
  - Guard tokens—never log secrets.
  - Prefer UTC for dates and day boundaries.
  - Add concise logs around network calls and callbacks.

## License
- MIT.
