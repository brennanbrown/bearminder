# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Added
- App menubar visibility fix and explicit AppKit entry point (`AppTemplate/Main.swift`).
- Status item controller with reliable 🐻 emoji title fallback.
- Settings window with Keychain-backed Bear and Beeminder tokens (`AppTemplate/SettingsWindowController.swift`).
- URL callback registration and coordinator (`AppDelegate+URLHandling.swift`, `BearCallbackCoordinator`).
- Bear integration that:
  - Searches broadly via x-callback-url and parses JSON `notes`.
  - Filters notes to today (UTC) by `modificationDate`.
  - Fetches per-note bodies and computes word counts from `text` or `note`.
  - Captures `creationDate` and `lastModified` in `Models.BearNoteMeta`.
- Daily delta logic that computes today’s words against yesterday’s end-of-day baselines; skips posting when delta is 0.
- Beeminder client with correct form encoding for multi-line comments.
- Keychain writes use `kSecAttrAccessibleAfterFirstUnlock` to reduce repeated prompts.
- Comprehensive README for users and developers.
 - Hourly background sync and on-demand sync (`Sources/SyncManager/SyncManager.swift`) with status notifications.
 - Last sync time in the menu and a status dot (green/yellow/red) in `StatusItemController`.
 - Settings: tag filters, sync frequency presets (30/60/120m), Start at Login toggle.
 - Settings: Test button to validate Beeminder credentials and Bear token presence.
 - Combined Keychain tokens (single item `service="bearminder"`, `account="tokens"`) to minimize prompts; Settings includes “Combine Tokens.”
 - Offline queue for Beeminder datapoints with discreet notifications; queued datapoints are flushed on next successful post.

### Changed
- Post only today’s delta to Beeminder and include a concise two-line summary comment.
- Improved logging around callbacks, per-note baseline/delta, and posting.
 - Unified scheduled and manual sync via a shared performer so both paths behave identically.
 - Beeminder comments standardized to a single line.

### Fixed
- Xcode scheme/project regeneration and missing `_main` linker errors.
- Menubar icon not appearing due to lifecycle ambiguity.
- Newline encoding in Beeminder comments.
 - Core Data thread-safety issues by using a background context and `performAndWait`.

### Planned
- Backoff and retry strategy for network/rate limit errors beyond the basic queue.
- Code signing + hardened runtime; Sparkle auto-updater.

### Changed
- CLI (`bearminder-cli`) now reads credentials from `ConfigLoader` (local file first, env vars as fallback) and performs a real POST when credentials are present.

[Unreleased]: https://github.com/brennanbrown/bearminder/compare/HEAD...HEAD
