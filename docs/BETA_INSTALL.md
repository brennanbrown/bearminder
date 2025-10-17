# Beta Installation Guide

Welcome, beta tester! 🎉 Thank you for helping test BearMinder.

## System Requirements
- macOS 12.0 (Monterey) or later
- Bear app (free or pro version)
- Active Beeminder account

## Installation Steps

### 1. Download the App
1. Go to the [Releases page](https://github.com/brennanbrown/bearminder/releases)
2. Download the latest `BearMinder.zip` file
3. Unzip by double-clicking the downloaded file

### 2. Bypass Gatekeeper (Required)
Since this is an unsigned beta, macOS will block it initially:

1. **Move BearMinder.app to your Applications folder** (optional but recommended)
2. **Right-click** (or Control-click) on BearMinder.app
3. Select **Open** from the menu
4. Click **Open** in the dialog that appears

You only need to do this once. After the first launch, you can open it normally.

**Alternative method if right-click doesn't work:**
```bash
xattr -cr /Applications/BearMinder.app
```

### 3. Initial Setup
1. The 🐻 icon should appear in your menubar
2. Click 🐻 → **Settings**
3. Fill in:
   - **Beeminder Username**: Your Beeminder username
   - **Beeminder API Token**: Get from https://www.beeminder.com/api/v1/auth_token.json
   - **Goal Name**: The slug of your goal (e.g., `writing`)
   - **Bear API Token**: In Bear, go to Help → Advanced → API Token → Copy
4. Click **Save**
5. When macOS asks for Keychain access, click **Always Allow** (this prevents repeated prompts)

### 4. Test Your First Sync
1. Write something in Bear (or edit an existing note)
2. Click 🐻 → **Sync Now**
3. Check your Beeminder goal – you should see a new datapoint!

## Troubleshooting

### Bear Pops Up During Sync
Enable "Use AppleScript mode" in Settings to prevent Bear from coming to the foreground.

### Keychain Keeps Asking for Permission
1. Open **Keychain Access** app
2. Search for "bearminder"
3. Double-click the item, go to **Access Control** tab
4. Add BearMinder.app to the allowed apps
5. Click **Save Changes**

### No Datapoint Posted
- Make sure you wrote in Bear **today** (UTC timezone)
- Check that notes were modified today
- Verify your tokens are correct (Settings → Test button)

### App Won't Open
Try running this command in Terminal:
```bash
xattr -cr /Applications/BearMinder.app
```

## What to Report

Please report issues on GitHub: https://github.com/brennanbrown/bearminder/issues

Include:
- macOS version (Apple menu → About This Mac)
- Bear version
- What you were doing when the issue occurred
- Any error messages from the menubar or Console.app

## Privacy Note
- Your tokens are stored in macOS Keychain (not in the app)
- No analytics or tracking
- All syncing happens directly between your Mac, Bear, and Beeminder

## Uninstalling
1. Quit BearMinder (click 🐻 → Quit)
2. Delete BearMinder.app from Applications
3. (Optional) Remove Keychain items:
   - Open Keychain Access
   - Search for "bearminder", "bear", and "beeminder"
   - Delete the items

---

Thank you for beta testing! Your feedback helps make BearMinder better for everyone. 🙏
