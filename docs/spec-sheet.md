# Bear to Beeminder Word Count Integration - Technical Specification

# Bear to Beeminder Word Count Integration - Technical Specification

## Overview
Automated system to track daily word count from Bear notes app and sync to Beeminder goal with detailed metadata, running twice daily.

## User Experience - How Someone Would Actually Use This

### Initial Setup (One-time)
1. **Bear Setup:**
   - Install Bear app on Mac/iOS
   - Generate API token: macOS: Help → Advanced → API Token → Copy Token
   - Start writing notes with consistent tagging (optional but recommended)

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
- **Frequency**: 2 updates per day (morning recap + evening final count)
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
- **Morning Update (9:00 AM)**: Previous day final tally
- **Evening Update (9:00 PM)**: Current day progress

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

## Graphical User Interface (GUI) Application

### Desktop Application (Electron/Native)
**Main Dashboard:**
- **Connection Status Panel**: Green/red indicators for Bear and Beeminder API connections
- **Today's Progress**: Real-time word count with visual progress bar toward daily goal
- **Quick Stats**: Current streak, weekly average, monthly total
- **Recent Activity Feed**: Last 5 sync events with timestamps and word counts

**Setup Wizard:**
- Step 1: Welcome screen explaining the integration
- Step 2: Bear API token input with "Test Connection" button
- Step 3: Beeminder credentials with goal selection dropdown
- Step 4: Preferences (sync times, tag filters, notification settings)
- Step 5: Confirmation screen with test sync option

**Settings Panel:**
- **Sync Schedule**: Custom time picker for morning/evening syncs
- **Tag Filtering**: Checkbox list of all Bear tags, ability to include/exclude specific tags
- **Notification Preferences**: Desktop alerts for sync events, writing reminders
- **Data Export**: Button to export historical sync data as CSV
- **Advanced Options**: Requestid format, retry settings, debug mode

**Live Monitoring:**
- **Writing Session Tracker**: Real-time word count as user types in Bear (if technically feasible)
- **Daily Timeline**: Visual timeline showing when writing occurred throughout the day
- **Goal Visualization**: Mini Beeminder graph embedded in the app
- **Tag Cloud**: Visual representation of most-used writing tags

### Mobile Companion App (iOS)
**Since Bear has strong iOS presence:**
- **Widget Support**: iOS widget showing today's word count and streak
- **Quick Sync Button**: Manual sync trigger for immediate gratification
- **Push Notifications**: Gentle reminders when behind on writing goals
- **Stats Sharing**: Share writing achievements to social media

### Web Dashboard (Optional)
**For users who prefer browser access:**
- **Login via Beeminder OAuth**: Secure authentication using existing Beeminder account
- **Historical Analytics**: Interactive charts showing writing patterns over time
- **Tag Analysis**: Breakdown of writing by category/topic
- **Export Tools**: Download data in multiple formats (CSV, JSON, PDF report)

### GUI Technical Architecture

**Frontend Framework Options:**
- **Electron + React**: Cross-platform desktop app with web technologies
- **Swift (macOS) / SwiftUI**: Native Mac app for better system integration
- **Tauri + Rust**: Lightweight alternative to Electron with better performance

**Key GUI Components:**
```
MainWindow/
├── StatusBar (connection indicators)
├── Dashboard (today's progress)
├── SyncLog (recent activity)
├── Settings (configuration panel)
└── About (version info, help links)

SetupWizard/
├── Welcome
├── BearConnection
├── BeeminderConnection  
├── Preferences
└── Confirmation
```

**Data Binding:**
- Real-time updates from background sync service
- Local SQLite database for GUI state persistence
- WebSocket or file watching for live Bear data updates

### User Experience Enhancements

**Visual Feedback:**
- **Progress Animations**: Smooth transitions when word counts update
- **Success Celebrations**: Confetti animation when daily goal reached
- **Streak Visualizations**: Fire emoji chains for consecutive days
- **Writing Heat Map**: GitHub-style contribution graph for writing activity

**Accessibility:**
- **Keyboard Shortcuts**: Quick access to all major functions
- **Screen Reader Support**: Proper ARIA labels and semantic HTML
- **High Contrast Mode**: Dark/light theme support
- **Font Scaling**: Adjustable text size for readability

**Error Handling UI:**
- **Connection Issues**: Clear error messages with troubleshooting steps
- **API Rate Limits**: Progress bars showing wait times
- **Sync Conflicts**: User-friendly resolution dialogs
- **Backup/Recovery**: One-click data backup and restore options

### Installation & Distribution

**Package Distribution:**
- **macOS**: DMG installer with proper code signing
- **Windows**: NSIS installer with automatic updates
- **Linux**: AppImage for universal compatibility
- **iOS**: TestFlight beta program, eventual App Store submission

**Auto-Update System:**
- Background update checking
- User notification for available updates
- Seamless update installation with data migration

**Getting Started Flow:**
1. Download installer from project website
2. Run setup wizard (5 minutes max)
3. Test sync with sample data
4. Start writing in Bear as normal
5. Watch data flow into Beeminder automatically

This GUI approach transforms the integration from a "technical tool" into a **delightful writing productivity app** that happens to use Bear and Beeminder as backends.

## Future Enhancements

### Phase 2 Features
- Integration with other writing apps (Obsidian, Notion, Google Docs) as fallbacks
- Writing streak tracking and celebrations with social sharing
- Goal adjustment recommendations based on writing patterns
- Mobile notifications for writing reminders and streak maintenance
- Collaborative features for writing groups/accountability partners

### Advanced Analytics
- Writing velocity trends with predictive modeling
- Tag-based productivity insights and topic recommendations
- Optimal writing time identification with calendar integration
- Progress tracking toward larger writing projects (books, thesis, etc.)
- Word complexity analysis and readability scoring