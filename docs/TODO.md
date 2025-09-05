# TODO / Roadmap

This file tracks what's done and what's next for BearMinder. See `docs/spec-sheet.md` for the full specification.

## Milestones

### M1: Core CLI + Dry-Run Pipeline (Current)
- [x] Project scaffold and package structure (`bearminder/`)
- [x] Config loading (`config.yaml`, `.env`)
- [x] SQLite schema and helpers (`note_snapshots`, `sync_log`)
- [x] Bear integration stub with simulated data when `debug=true`
- [x] Delta calculation and basic metadata (titles, tags)
- [x] Beeminder client with dry-run mode
- [x] CLI commands: `init-db`, `sync-once`, `schedule`
- [x] APScheduler for 9AM/9PM runs
- [x] README and quickstart

### M2: Real Bear Integration (Local, SQLite)
- [x] Implement local read-only SQLite reader for Bear database (`bearminder/bear_collector.py`)
- [x] Fallback handling and helpful logging when DB not found or unreadable
- [x] Robust time filtering (since last successful sync)
- [x] Prefer `ZTITLE` over `ZSUBTITLE` for titles
- [x] De-duplicate titles in comment output
- [ ] Tag parsing from DB (deferred; currently omitted by design)
- [ ] Exponential backoff and error capture (DB open/query)

### M3: Beeminder Comment Enrichment
- [x] Session detection (AM/PM split)
- [x] "Top Note" title and word count
- [x] Switch to single-line compact comments for tooltip readability
- [x] Zero-activity comment text
- [x] Duplicate datapoint prevention (recent fetch + compare)
- [x] Title truncation per `metadata` config
- [ ] Tag truncation and formatting per `metadata` config

### M4: Reliability & State
- [x] Persist per-note previous counts correctly across runs
- [ ] Timezone-safe timestamps (UTC in storage, local for display)
- [ ] Retry/queue on network failures and rate limits
- [ ] Structured logging and debug mode toggles
- [ ] CSV export of historical sync data

### M5: GUI (first cut)
- [x] Decide stack (Tauri + React)
- [x] Scaffold Tauri + React app under `gui/` and verify build
- [x] Minimal shell app with Status view
- [x] Status view: last sync time, words posted, notes scanned, tags count, result + details
- [x] Controls: Run now, Recount last hour, Toggle dry-run, Open config.yaml, Open data folder
- [x] Onboarding hero with basic instructions and CTA (dismissible)
- [x] Beeminder credentials form saved to `.env` via Tauri (username, goal, token)
- [x] Background: launch scheduler via macOS launchd (install/uninstall scripts, logs, README docs)
- [ ] GUI: show live background status and control (service state, last run)
- [ ] Packaging for macOS (codesign optional for dev)

## Detailed Task Checklist

- [x] `bearminder/bear_collector.py`: Local SQLite reader with schema heuristics and Apple epoch conversion
- [x] `bearminder/word_calculator.py`: Session logic and richer metadata output
- [x] `bearminder/beeminder_sync.py`: Timestamped datapoints and duplicate checks
- [x] `bearminder/scheduler.py`: Twice-daily scheduling, comment formatting
- [x] `bearminder/main.py`: Added `post-test` and `--ignore-last-sync`
- [x] `bearminder/main.py`: Compact comment with safe title truncation and whitespace cleanup
- [x] `.gitignore` covers data/, venv, caches
- [ ] Tests for delta calculation and comment formatting
- [ ] Logging improvements and error handling utilities

### GUI Tasks
- [x] Create `gui/` with chosen stack scaffold
- [~] IPC/CLI bridge: Added `run_sync` Tauri command to invoke `python -m bearminder.main sync-once`
- [x] Minimal Status screen in `gui/src/App.tsx` to trigger sync and show output
- [x] File-based status (`data/status.json`) and GUI `read_status` Tauri command
- [x] Loading spinners on actions; disabled + aria-busy states
- [x] Warning banner when Bear DB not found, with buttons to open folder and `.env`
- [x] Background install/uninstall scripts (launchd) and README instructions
- [ ] Wizard screens and validation
- [ ] Settings editor (loads/saves `config.yaml`)
- [x] Basic theming, primary button, gradient hero; constrained form width

## Nice-to-haves
- [ ] Streak tracking and celebrations
- [ ] Tag analytics and word velocity trends
- [ ] Export/import settings and data

## Notes
- Keep secrets in `.env` or Keychain; avoid plaintext tokens in repo.
- Prefer UTC storage; convert to local timezones in UI/console.
