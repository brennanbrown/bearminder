# Bear → Beeminder Word Tracker – TODO

Status legend: [ ] pending • [~] in progress • [x] done

## Project Setup
- [x] Confirm stack: Swift 5/AppKit, macOS 12+, Core Data, Keychain, URLSession
- [x] Initialize Swift Package core modules (SPM targets for Models, Clients, Persistence, Sync, Keychain, Logging)
- [x] Initialize Xcode macOS menu bar app project (AppKit lifecycle) via XcodeGen (`Apps/BearMinder/project.yml`)
- [ ] Configure Login Item (SMAppService) for Start at Login
- [x] Add gitignored local credentials storage (`local/credentials.json`) and `Config` loader

## UI
- [x] NSStatusItem with menu: Status, Sync Now, Settings, Open Beeminder, Quit (emoji title fallback)
- [x] Status indicator dot (green/yellow/red) and Last Sync line
- [x] Settings window (AppKit):
  - [x] Bear API token (Keychain)
  - [x] Beeminder username + token (Keychain)
  - [x] Goal name
  - [x] Tag filters (optional)
  - [x] Sync frequency (hourly by default; presets 30m/2h; optional fixed 9am/9pm)
  - [x] Test credentials button
- [x] App template: `StatusItemController.swift` and `SettingsWindowController.swift`

- [x] SyncManager
  - [x] Hourly background timer + on-demand sync trigger
  - [ ] Backoff + retry strategy
  - [x] Persist last successful sync timestamp
- [~] Persistence (Core Data)
  - [x] Model: `daily_snapshots`, `note_tracking`
  - [ ] DAO layer + migrations
- [x] Bear integration
  - [x] x-callback-url search + per-note fetch
  - [x] Filter to today (UTC) by `modificationDate`
  - [x] Word count from callback body (`text` or `note`)
  - [x] Seed `creationDate` and `lastModified`
- [x] Daily delta logic
  - [x] Baseline = yesterday’s end-of-day; if none, 0
  - [x] Fix-up for notes created today (baseline 0)
- [x] BeeminderClient
  - [x] POST datapoints with idempotent `requestid` (date-based)
  - [x] Proper form encoding so newlines render on Beeminder
  - [ ] Error handling for rate limits/network

## Error Handling & Notifications
- [x] Discreet user notifications on failed post and on queue flush
- [x] Offline queue for datapoints when Beeminder unavailable (basic)
- [ ] Failure streak threshold (notify only after 2–3 consecutive failures)
- [x] Robust logging (local only, no sensitive data)

## Testing & Distribution
- [x] Manual test end-to-end with real account/goal
- [ ] Performance sanity checks (<10MB idle, <15MB during sync)
- [ ] Sparkle auto-updater (optional post-MVP)
- [ ] Code signing & hardened runtime

## Stretch / Post-MVP
- [ ] Tag-based filtering UI & logic
- [ ] Streaks and simple celebratory notifications
- [ ] Historical dashboard (Phase 2)

## Notes / Open Questions
- Bear background access via x-callback-url may bring Bear to foreground; consider custom URL scheme callback or AppleScript fallback if needed.
- Settings UI: AppKit vs SwiftUI hosted inside AppKit window.
- Default schedule: hourly, allow presets and manual sync.

## AppTemplate Progress
- [x] `AppDelegate` integrates Keychain + Config and seeds local creds.
- [x] `LocalConfigLoader.swift` created.
- [x] `BearXCallbackClient.swift` and URL scheme registration.
- [x] URL callback handling in `AppDelegate+URLHandling` + coordinator.
- [x] Replace in-memory persistence with full Core Data stack in app target (thread-safe background context).

## Integrations & UX
- [x] Combined Keychain tokens (single item) to minimize prompts; Settings has "Combine Tokens"
- [ ] Optional AppleScript fallback for missing note text
