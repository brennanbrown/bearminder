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

### Changed
- Post only today’s delta to Beeminder and include a concise two-line summary comment.
- Improved logging around callbacks, per-note baseline/delta, and posting.

### Fixed
- Xcode scheme/project regeneration and missing `_main` linker errors.
- Menubar icon not appearing due to lifecycle ambiguity.
- Newline encoding in Beeminder comments.

### Planned
- Hourly background sync (`SyncManager`) and last-sync status in the menu.
- Tag filter UI and logic.
- Error notifications and offline queue for datapoints.
- Code signing + hardened runtime; Sparkle auto-updater.

### Changed
- CLI (`bearminder-cli`) now reads credentials from `ConfigLoader` (local file first, env vars as fallback) and performs a real POST when credentials are present.

[Unreleased]: https://github.com/brennanbrown/bearminder/compare/HEAD...HEAD
