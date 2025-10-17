# BearMinder v0.1.0-beta.1 (Beta Release)

> **⚠️ Beta Software**: This is a pre-release version for testing. Not code-signed or notarized.

BearMinder automatically syncs your Bear writing to Beeminder. Write in Bear, track in Beeminder – that's it.

## 🎯 What's New in This Release

- ✅ Automatic hourly syncing (configurable: 30min/1hr/2hr)
- ✅ Exponential backoff retry for network issues
- ✅ Rate limit handling (429 responses)
- ✅ Offline queue with automatic retry
- ✅ Core Data persistence with lightweight migrations
- ✅ AppleScript mode option (prevents Bear from popping up)
- ✅ Start at Login support (macOS 13+)

## 📥 Installation

**System Requirements:**
- macOS 12.0+ (Monterey or later)
- Bear app (free or pro)
- Beeminder account

**Quick Install:**
1. Download `BearMinder.zip` below
2. Unzip and move BearMinder.app to Applications
3. **Right-click** → Open (bypasses Gatekeeper)
4. Follow the [Beta Installation Guide](https://github.com/brennanbrown/bearminder/blob/main/docs/BETA_INSTALL.md)

## 🐛 Known Issues

- Not code-signed (requires Gatekeeper bypass on first launch)
- Keychain prompts can be persistent (workaround in docs)
- Some Sendable warnings in Xcode logs (cosmetic, doesn't affect functionality)

## 📝 Beta Testing

This is a **beta release** for testing. Please report issues at:
https://github.com/brennanbrown/bearminder/issues

**What to test:**
- Daily writing workflow
- Multiple syncs per day
- Network issues / offline behavior
- Different macOS versions (12, 13, 14, 15)

## 📚 Documentation

- [Beta Installation Guide](https://github.com/brennanbrown/bearminder/blob/main/docs/BETA_INSTALL.md)
- [Full README](https://github.com/brennanbrown/bearminder/blob/main/README.md)
- [Spec Sheet](https://github.com/brennanbrown/bearminder/blob/main/docs/spec-sheet.md)

## 🙏 Thank You

Thank you for being an early tester! Your feedback helps make BearMinder better for everyone.

---

**Full Changelog**: https://github.com/brennanbrown/bearminder/commits/v0.1.0-beta.1
