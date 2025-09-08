# Bear to Beeminder Word Count Integration - Technical Specification

# Bear to Beeminder Word Count Integration - Technical Specification

## Overview
Automated system to track daily word count from Bear notes app and sync to Beeminder goal with detailed metadata, running hourly in the background, with an on-demand "Sync now" action from the menubar.

## User Experience - How Someone Would Actually Use This

### Initial Setup (One-time)
1. **Bear Setup:**
   - Install Bear app on Mac/iOS
   - Generate API token: macOS: Help → Advanced → API Token → Copy Token
   - Start writing notes# Bear to Beeminder Word Count Tracker - Menu Bar App Specification

## Overview
Lightweight macOS menu bar application that silently tracks daily word count from Bear notes and syncs to Beeminder automatically. Runs invisibly in the background with minimal system resources.

## User Experience - Effortless Word Tracking

### Installation & Setup (One-time, 2 minutes)
1. **Download and launch** the app (single .app file)
2. **Menu bar icon appears** - 🐻 bear emoji in system menu bar
3. **Click icon → "Settings"** to configure:
   - Bear API token (copied from Bear app settings)
   - Beeminder username and auth token
   - Goal name (e.g., "writing")
   - Which tags to track (optional - defaults to all notes)
4. **Done** - app disappears into background, starts at login automatically

### Daily Experience (Zero friction)
1. **Write in Bear normally** - no workflow changes whatsoever
2. **Menu bar shows sync status** - click 🐻 icon to see:
   ```
   Today: 423 words written
   Last sync: 2 minutes ago ✅
   Goal status: 127 words ahead
   
   [Sync Now] [Settings]
   ```
3. **Automatic syncing every hour** + on-demand via "Sync Now"
4. **Rich data appears in Beeminder** with writing context and metadata

### Menu Bar Interface
**Default state:** 🐻 (bear emoji, no text to save space)
**Click behavior:** Show popup with current status and controls
**Status indicator:** Small colored dot on icon (green=synced, yellow=syncing, red=error)

## Technical Architecture

### macOS Menu Bar App (Swift/Objective-C)
- **NSStatusItem** - menu bar presence
- **Launch daemon** - start at login automatically  
- **Background timer** - hourly sync schedule
- **Minimal memory footprint** - < 10MB RAM usage
- **Low CPU usage** - only active during sync operations
- **System notifications** - discrete alerts for sync errors only

### Bear Integration (x-callback-url)
**Authentication:**
- Store Bear API token in macOS Keychain
- Token must be generated per-platform (macOS specific)

**Data Collection Strategy:**
```swift
// Hourly sync process:
1. Query Bear for today's modified notes
2. Calculate word count delta since last sync
3. Store note metadata (titles, tags, timestamps)
4. Send cumulative daily count to Beeminder
```

**Key API Calls:**
- `bear://x-callback-url/today?token={token}` - Today's notes
- `bear://x-callback-url/search?term={term}&token={token}` - Filtered notes by tag
- `bear://x-callback-url/open-note?id={id}&token={token}` - Individual note content for word counting

### Beeminder Integration (REST API)
**Authentication:** Store auth token in macOS Keychain

**Sync Strategy:**
```
POST https://www.beeminder.com/api/v1/users/{user}/goals/{goal}/datapoints.json
- value: Total daily word count (cumulative)
- comment: Rich metadata about today's writing
- requestid: Date-based unique ID for idempotency
- timestamp: Current time
```

### Data Management
**Local Storage (Core Data/SQLite):**
```sql
CREATE TABLE daily_snapshots (
    date TEXT PRIMARY KEY,           -- YYYY-MM-DD
    total_words INTEGER,             -- Cumulative daily count
    notes_modified INTEGER,          -- Number of notes touched
    top_tags TEXT,                   -- JSON array of most used tags
    sync_status TEXT,                -- 'pending', 'synced', 'error'
    last_updated TIMESTAMP
);

CREATE TABLE note_tracking (
    note_id TEXT,
    date TEXT,
    previous_word_count INTEGER,
    current_word_count INTEGER,
    PRIMARY KEY (note_id, date)
);
```

## Menu Bar Popup Interface

### Status View (Default)
```
┌─────────────────────────────────┐
│ 🐻 Bear → Beeminder Word Tracker│
├─────────────────────────────────┤
│ Today: 847 words written        │
│ Goal: 250 words/day             │
│ Status: 597 words ahead! 🎉     │
│                                 │
│ Last sync: 3 minutes ago ✅     │
│ Next sync: in 57 minutes        │
│                                 │
│ Recent notes:                   │
│ • "Blog post draft" (423 words) │
│ • "Daily journal" (312 words)   │
│ • "Meeting notes" (112 words)   │
│                                 │
│ [🔄 Sync Now] [⚙️ Settings]     │
│ [📊 Open Beeminder] [❌ Quit]   │
└─────────────────────────────────┘
```

### Settings View (Click "Settings")
```
┌─────────────────────────────────┐
│ ⚙️ Bear → Beeminder Settings     │
├─────────────────────────────────┤
│ Bear API Token:                 │
│ [abc123-def456-ghi789]          │
│                                 │
│ Beeminder Username:             │
│ [brennanbrown]                  │
│                                 │
│ Beeminder Auth Token:           │
│ [xyz789-uvw456-rst123]          │
│                                 │
│ Goal Name:                      │
│ [writing]                       │
│                                 │
│ Track only these tags:          │
│ [#writing #blog #journal]       │
│ ☑️ Track all notes (ignore tags)│
│                                 │
│ Sync frequency:                 │
│ ◉ Every hour ◯ Every 30 min     │
│ ◯ Every 2 hours                 │
│                                 │
│ [💾 Save] [🔙 Back] [🧪 Test]   │
└─────────────────────────────────┘
```

## Background Operations

### Sync Process (Every Hour + On-Demand)
1. **Check Bear connectivity** - validate API token works
2. **Query today's notes** - get all modified notes for current date
3. **Calculate word deltas** - compare with stored previous counts
4. **Update local database** - store new counts and metadata
5. **Send to Beeminder** - POST daily cumulative total with rich comment
6. **Update menu bar** - refresh status indicator
7. **Handle errors silently** - log issues, show notification only if persistent

### System Resource Management
- **Timer-based sync** - `NSTimer` with 1 hour intervals
- **Efficient queries** - only fetch modified notes since last check
- **Minimal memory usage** - release objects immediately after processing
- **Background processing** - use `NSOperationQueue` for API calls
- **Graceful degradation** - continue working if either API is temporarily unavailable

### Error Handling
- **Bear unreachable:** Cache locally, retry next sync
- **Beeminder API down:** Queue data points, send when available
- **Authentication fails:** Show notification, open settings automatically
- **Goal doesn't exist:** Offer to create goal or update settings
- **Network issues:** Exponential backoff retry strategy

## Beeminder Data Point Format

### Rich Comment Template
```
📝 {total_words} words across {note_count} notes

✍️ Top sessions:
• "{highest_word_note}" ({word_count} words)
• "{second_note}" ({word_count} words)

🏷️ Tags: #{tag1} #{tag2} #{tag3}

📊 Progress: {percentage}% of daily goal
⏰ Most active: {peak_writing_time}

🐻 via Bear → Beeminder
```

### Example Data Point
```json
{
  "value": 847,
  "comment": "📝 847 words across 4 notes\n\n✍️ Top sessions:\n• \"Blog post about productivity\" (423 words)\n• \"Daily reflection journal\" (312 words)\n\n🏷️ Tags: #writing #blog #productivity #reflection\n\n📊 Progress: 339% of daily goal\n⏰ Most active: 2:00-4:00 PM\n\n🐻 via Bear → Beeminder",
  "requestid": "bear-sync-2025-09-07",
  "timestamp": 1725724800
}
```

## Development Stack

### Primary Technologies
- **Language:** Swift 5.0+ (native macOS performance)
- **Framework:** Cocoa/AppKit for menu bar integration
- **Storage:** Core Data for local persistence
- **Security:** Keychain Services for credential storage
- **Networking:** URLSession for REST API calls

### Build Configuration
- **Deployment target:** macOS 12.0+ (wide compatibility)
- **Architecture:** Universal Binary (Intel + Apple Silicon)
- **Code signing:** Developer ID for distribution outside App Store
- **Sandboxing:** Minimal permissions (network access only)

### Distribution
- **Direct download:** Single .app file from website
- **Auto-updater:** Sparkle framework for seamless updates
- **File size:** < 5MB total application size
- **Installation:** Drag-and-drop to Applications folder

## Privacy & Security

### Data Handling
- **Local processing only** - never store note content remotely
- **Encrypted credentials** - all API tokens in macOS Keychain
- **Minimal data collection** - only word counts and metadata
- **No analytics** - completely private operation
- **User control** - easy to disable/uninstall completely

### API Security
- **HTTPS only** - all external communications encrypted
- **Token rotation** - support for updating credentials easily
- **Graceful failures** - no sensitive data in logs or error messages

## Success Metrics

### Performance Targets
- **Memory usage:** < 10MB baseline, < 15MB during sync
- **CPU usage:** < 1% average, < 5% during active sync
- **Network usage:** < 100KB per sync operation
- **Startup time:** < 2 seconds to menu bar appearance
- **Sync reliability:** > 99.5% successful sync rate

### User Experience Goals
- **Setup time:** < 3 minutes from download to first sync
- **Daily interaction:** Zero required user actions
- **Status clarity:** Always know sync state at a glance
- **Error recovery:** Automatic resolution of 95%+ issues
- **Invisibility:** Works perfectly without user awareness with consistent tagging (optional but recommended)

2. **Beeminder Setup:**
   - Create Beeminder account and "writing" goal (custom goal type)
   - Set daily word count target (e.g., 250 words/day)
   - Get personal auth token from: `https://www.beeminder.com/api/v1/auth_token.json`
   - Configure goal to accept manual data entry

3. **Integration Setup:**
   - Download/install the Bear-Beeminder sync tool
   - Configure with Bear API token and Beeminder credentials
   - Set schedule preferences (default: 9 AM and 9 PM)
   - Choose which tags to track (or all notes)

### Daily Workflow
1. **Write in Bear as normal** - no behavior change needed
   - Create new notes or edit existing ones
   - Use tags like #writing #blog #journal #work for categorization
   - Write anywhere from 10 to 1000+ words per day

2. **Automatic tracking happens twice daily:**
   - **Morning sync (9 AM)**: Reviews previous day's writing, sends final count to Beeminder
   - **Evening sync (9 PM)**: Reviews current day's progress, sends intermediate update

3. **Beeminder updates automatically:**
   - Data points appear on Beeminder graph with rich context
   - Comments show what you wrote about, which tags used, session details
   - Beeminder's standard reminder system works (email/SMS when falling behind)

### What the User Sees
**In Bear:** Normal writing experience, no changes to workflow

**In Beeminder:** Rich data points like:
```
📝 847 words | 📚 4 notes | 🏷️ 6 tags

Notes: "Blog post draft", "Daily journal", "Project brainstorm"...
Tags: #writing #blog #personal #productivity #ideas #draft
Sessions: 312AM + 535PM  
Top Note: "Blog post draft" (423 words)
```

**Benefits:**
- No manual data entry required
- Rich context about writing habits and topics
- Beeminder's financial commitment keeps you accountable
- Historical data shows writing patterns over time
- Works across all Bear-supported platforms (Mac, iOS, iPad)

## Core Requirements

### Data Collection
- **Source**: Bear app notes via x-callback-url API
- **Metric**: Total word count written per day (cumulative)
- **Frequency**: Hourly background sync + on-demand via "Sync now" from the menubar
- **Data Point Value**: Daily word count delta (new words written since last update)

### Metadata Collection
For each data point, capture:
- **Notes Modified**: List of note titles that were edited/created
- **Tags Used**: All unique tags from modified notes
- **Note Categories**: Types of writing (journal, blog, project notes, etc.)
- **Time Ranges**: When writing sessions occurred
- **Session Count**: Number of distinct writing sessions

## Technical Architecture

### 1. Bear API Integration
**Endpoints to Use:**
- `bear://x-callback-url/search` - Find notes modified today
- `bear://x-callback-url/open-note` - Get individual note content/stats
- `bear://x-callback-url/grab-url` - Get note metadata

**Data to Extract per Note:**
- Note title
- Word count
- Character count
- Last modified timestamp
- Tags
- Creation date

### 2. Data Processing Logic
```
Daily Word Count Calculation:
1. Query all notes modified since last run
2. For each note:
   - Get current word count
   - Compare with stored previous word count
   - Calculate delta (new words added)
3. Sum all deltas for total daily new words
4. Generate metadata summary
```

### 3. Beeminder Integration
**API Endpoint**: `POST /api/v1/users/{username}/goals/{goalname}/datapoints`

**Data Point Structure:**
- `value`: Daily word count (integer)
- `comment`: Rich metadata string (see format below)
- `timestamp`: Update time (twice daily)

## Scheduling & Execution

### Update Schedule
- **Hourly background sync**: Regular collection and posting without user interaction
- **On-demand sync**: User-initiated via menubar "Sync now" action

### State Management
**Local Storage Requirements:**
- Previous word counts per note (to calculate deltas)
- Last successful sync timestamp
- Daily running totals
- Error logs

## Data Point Comment Format

### Template Structure
```
📝 {total_words} words | 📚 {notes_count} notes | 🏷️ {tags_count} tags

Notes: {note_titles_truncated}
Tags: #{tag1} #{tag2} #{tag3}...
Sessions: {morning_words}AM + {evening_words}PM
Top Note: "{highest_word_count_note}" ({word_count} words)
```

### Example Output
```
📝 847 words | 📚 4 notes | 🏷️ 6 tags

Notes: "Blog post draft", "Daily journal", "Project brainstorm"...
Tags: #writing #blog #personal #productivity #ideas #draft
Sessions: 312AM + 535PM  
Top Note: "Blog post draft" (423 words)
```

## Error Handling & Edge Cases

### Bear App States
- **App not running**: Launch Bear, wait for startup
- **No notes modified**: Send 0 value with "No writing today" comment
- **API timeout**: Retry with exponential backoff
- **Permission denied**: Log error, notify user

### Beeminder API Issues
- **Rate limiting**: Queue requests, respect limits
- **Network failures**: Store locally, retry on next run
- **Duplicate data points**: Check timestamp before sending
- **Goal doesn't exist**: Create goal or fail gracefully

### Data Integrity
- **Word count discrepancies**: Log for manual review
- **Missing notes**: Compare against previous successful run
- **Time zone handling**: Use consistent UTC timestamps
- **Backup data**: Export daily summaries to local file

## Implementation Components

### Core Scripts
1. **`bear_collector.py`** - Bear API interactions and data extraction
2. **`word_calculator.py`** - Delta calculations and state management  
3. **`beeminder_sync.py`** - API integration and data point creation
4. **`scheduler.py`** - Cron job management and execution orchestration
5. **`config.py`** - Settings, API keys, goal configuration

### Configuration Settings
```yaml
bear:
  callback_timeout: 30s
  retry_attempts: 3
  
beeminder:
  username: "your_username"
  goal_name: "writing"
  api_token: "your_token"
  
schedule:
  morning_time: "09:00"
  evening_time: "21:00"
  timezone: "America/Calgary"
  
metadata:
  max_note_titles: 5
  max_tags: 8
  truncate_length: 100
```

### Database Schema (SQLite)
```sql
CREATE TABLE note_snapshots (
    note_id TEXT PRIMARY KEY,
    title TEXT,
    word_count INTEGER,
    last_modified TIMESTAMP,
    tags TEXT,
    snapshot_date DATE
);

CREATE TABLE sync_log (
    sync_id INTEGER PRIMARY KEY,
    sync_time TIMESTAMP,
    total_words INTEGER,
    notes_processed INTEGER,
    beeminder_response TEXT,
    success BOOLEAN
);
```

## Security & Privacy

### API Key Management
- Store Beeminder API token in environment variables
- Use keychain/credential manager for sensitive data
- No plaintext storage of authentication

### Data Privacy
- Only process note metadata and word counts
- No full note content stored or transmitted
- Local processing only, minimal external API calls

## Success Metrics & Monitoring

### Health Checks
- Successful API connections to both Bear and Beeminder
- Data consistency across runs
- No missed scheduled executions
- Error rate < 5%

### User Experience
- Rich, informative Beeminder comments
- Accurate daily word count tracking  
- Minimal manual intervention required
- Clear error messages when issues occur

## Future Enhancements

### Phase 2 Features
- Web dashboard for historical data visualization
- Writing streak tracking and celebrations
- Goal adjustment based on writing patterns
- Integration with other writing apps as fallbacks
- Mobile notifications for writing reminders

### Advanced Analytics
- Writing velocity trends
- Tag-based productivity insights
- Optimal writing time identification  
- Progress toward larger writing projects