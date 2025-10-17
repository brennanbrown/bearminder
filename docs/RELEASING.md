# How to Create a Beta Release

This guide walks through creating a beta release for distribution.

## Step 1: Build the Release

```bash
# From the repo root
./scripts/build-release.sh
```

This will:
- Generate the Xcode project
- Build in Release configuration (unsigned)
- Create `build-release/BearMinder.zip`

The zip file will be at: `build-release/BearMinder.zip`

## Step 2: Create GitHub Release

1. **Go to GitHub Releases:**
   https://github.com/brennanbrown/bearminder/releases/new

2. **Tag the release:**
   - Tag version: `v0.1.0-beta.1` (increment as needed)
   - Target: `main` branch

3. **Release title:**
   - Example: `BearMinder v0.1.0-beta.1 (Beta Release)`

4. **Release description:**
   - Copy content from `.github/RELEASE_TEMPLATE.md`
   - Update version numbers and changelog as needed

5. **Upload the zip:**
   - Click "Attach binaries"
   - Upload `build-release/BearMinder.zip`

6. **Mark as pre-release:**
   - ✅ Check "This is a pre-release"

7. **Publish release**

## Step 3: Update Forum Post

Once the release is published:

1. Get the download link (will be something like):
   ```
   https://github.com/brennanbrown/bearminder/releases/download/v0.1.0-beta.1/BearMinder.zip
   ```

2. Update your Beeminder forum post with:
   - Direct download link
   - Link to beta installation guide
   - Link to the release page

Example forum post addition:
```markdown
**Download:** [BearMinder.zip](https://github.com/brennanbrown/bearminder/releases/download/v0.1.0-beta.1/BearMinder.zip)

**Installation guide:** [Beta Install Instructions](https://github.com/brennanbrown/bearminder/blob/main/docs/BETA_INSTALL.md)
```

## Step 4: Monitor Feedback

Watch for:
- GitHub issues: https://github.com/brennanbrown/bearminder/issues
- Forum comments
- Direct messages

## Future: Code Signing (Optional)

For a smoother user experience, consider:

1. **Apple Developer Account** ($99/year)
   - Enables code signing
   - Allows notarization (no Gatekeeper warnings)

2. **Notarization Process:**
   ```bash
   # Sign the app
   codesign --deep --force --sign "Developer ID" BearMinder.app
   
   # Create a notarization-ready zip
   ditto -c -k --keepParent BearMinder.app BearMinder.zip
   
   # Submit for notarization
   xcrun notarytool submit BearMinder.zip --keychain-profile "notary" --wait
   
   # Staple the ticket
   xcrun stapler staple BearMinder.app
   ```

3. **Benefits:**
   - Users can double-click to open (no right-click needed)
   - Appears as "verified" in macOS
   - Better for wider distribution

For beta testing, unsigned builds are fine. Users who are motivated to test will follow the bypass steps.
