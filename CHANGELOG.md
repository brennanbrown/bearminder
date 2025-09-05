# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog (https://keepachangelog.com/en/1.1.0/),
and this project adheres to Semantic Versioning (https://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Added
- Onboarding landing hero in `gui/src/App.tsx` with basic instructions and CTA (dismissible).
- Loading spinners and `aria-busy` for key actions (Sync now, Recount last hour, Refresh, Save settings).
- Bear DB auto-detection Tauri commands: `detect_bear_db`, `open_bear_db_folder`.
- GUI warning banner when Bear DB is not found with one-click actions to open data folder and `.env`.
- Docs: README section on configuring `BEAR_DB_PATH`; `.env.example` updated with `BEAR_DB_PATH` hint.
- `docs/TODO.md` updated to reflect completed GUI milestones.
- Background mode on macOS via `launchd`:
  - Scripts: `scripts/install_launchd.sh`, `scripts/uninstall_launchd.sh`
  - Runs `python -m bearminder.main schedule` at login, logs to `data/launchd.*.log`
  - README section "Background mode (macOS launchd)" with instructions
- macOS menu bar (tray) icon with actions: Open, Sync now, Open config, Open data, Quit.

### Changed
- GUI styling: accent colors, primary button, gradient hero, narrowed settings form.
- Tauri stack aligned to v2 across Rust crates and config (`tauri`, `tauri-build`, `tauri-plugin-opener`, `tauri.conf.json`).
- `run_sync` interpreter selection prefers `.venv/bin/python`, then `python3`, then `python`.

### Notes
- Upcoming work: scheduler integration surfaced in GUI, wizard screens, `config.yaml` editor, packaging.

### Fixed
- Build failures due to Tauri v1/v2 mismatch by aligning everything to Tauri v2.
- GUI sync failing when `python` missing by adding interpreter fallback logic in `run_sync`.

## [0.1.1] - 2025-09-03
### Added
- Real Bear integration via local, read-only SQLite database with schema heuristics and Apple-epoch conversion (`bearminder/bear_collector.py`).
- CLI `post-test` command to manually post a datapoint to Beeminder.
- CLI `sync-once --ignore-last-sync` flag to force a lookback window.
- Timezone fallback to UTC in `scheduler.py` and added `tzdata` dependency to ensure zoneinfo availability.

### Changed
- Switched Beeminder comments to a compact single-line format in both `sync_once` and scheduler for better tooltip rendering.

### Fixed
- Scheduler crash when `America/Calgary` tz not available (falls back to UTC, logs warning).

## [0.1.0] - 2025-09-03
### Added
- Initial project scaffold matching `docs/spec-sheet.md` core requirements
- Python package `bearminder/` with:
  - `config.py` (YAML + .env config loader)
  - `db.py` (SQLite schema and helpers)
  - `bear_collector.py` (debug stub for Bear notes)
  - `word_calculator.py` (delta calculations)
  - `beeminder_sync.py` (client with dry-run mode)
  - `scheduler.py` (APScheduler for morning/evening)
  - `main.py` (CLI commands: `init-db`, `sync-once`, `schedule`)
- `requirements.txt`, `README.md`, `config.yaml`, `.env.example`
- `docs/TODO.md` roadmap

### Notes
- Bear integration currently simulated when `debug=true`; real `bear://` implementation pending.
