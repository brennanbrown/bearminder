import AppKit
import KeychainSupport
import BeeminderClient

/// Manages the settings window for Bear → Beeminder configuration
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    // MARK: - UI Elements
    
    private var usernameField = NSTextField(string: "")
    private var goalField = NSTextField(string: "")
    private var syncPopup = NSPopUpButton()
    private var beeminderTokenField = NSSecureTextField(string: "")
    private var bearTokenField = NSSecureTextField(string: "")
    private var tagsField = NSTextField(string: "")
    private var startAtLoginCheckbox = NSButton(
        checkboxWithTitle: "Start at login",
        target: nil,
        action: nil
    )
    private var appleScriptModeCheckbox = NSButton(
        checkboxWithTitle: "Use AppleScript mode (prevents Bear from popping up)",
        target: nil,
        action: nil
    )

    // MARK: - Initialization
    
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 340),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Bear → Beeminder Settings"
        self.init(window: window)
        self.window?.delegate = self
        setupUI()
        loadValues()
    }

    // MARK: - Actions
    
    @objc
    private func onCombineTokens() {
        guard let window = self.window else { return }
        let keychain = KeychainStore()
        let beeminderToken = (try? keychain.getPassword(account: "token", service: "beeminder")) ?? ""
        let bearToken = (try? keychain.getPassword(account: "token", service: "bear")) ?? ""
        
        let alert = NSAlert()
        
        if !beeminderToken.isEmpty && !bearToken.isEmpty {
            try? keychain.setCombinedTokens(beeminder: beeminderToken, bear: bearToken)
            alert.messageText = "Combined tokens saved"
            alert.informativeText = """
            A single Keychain item (bearminder/tokens) was created. 
            Choose 'Always Allow' once to reduce future prompts.
            """
            alert.alertStyle = .informational
        } else {
            alert.messageText = "Missing tokens"
            alert.informativeText = """
            Could not find both individual tokens in Keychain. 
            Save both tokens in Settings first, then combine.
            """
            alert.alertStyle = .warning
        }
        
        alert.addButton(withTitle: "OK")
        alert.beginSheetModal(for: window) { _ in }
    }
    
    // MARK: - Window Management
    
    /// Displays the settings window
    func show() {
        guard let window = self.window else { return }
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - UI Setup
    
    private func setupUI() {
        guard let content = window?.contentView else { return }
        
        // Configure text fields
        configureTextFields()
        
        // Create grid layout
        let grid = NSGridView(views: createGridRows())
        grid.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(grid)
        
        // Configure constraints
        NSLayoutConstraint.activate([
            grid.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            grid.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            grid.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            grid.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -20)
        ])
        
        // Configure popup menu
        syncPopup.addItems(withTitles: ["Every 30 min", "Every hour", "Every 2 hours"])
        
        // Configure checkboxes
        startAtLoginCheckbox.target = self
        startAtLoginCheckbox.action = #selector(onToggleStartAtLogin(_:))
    }
    
    private func configureTextFields() {
        // Configure text field properties if needed
        [usernameField, goalField, beeminderTokenField, bearTokenField, tagsField].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.usesSingleLineMode = true
        }
    }
    
    private func createGridRows() -> [[NSView]] {
        [
            [createLabel("Beeminder Username:"), usernameField],
            [createLabel("Goal Name:"), goalField],
            [createLabel("Beeminder API Token:"), beeminderTokenField],
            [createLabel("Bear API Token:"), bearTokenField],
            [createLabel("Track only these tags (optional):"), tagsField],
            [createLabel("Sync Frequency:"), syncPopup],
            [startAtLoginCheckbox, NSView()],
            [appleScriptModeCheckbox, NSView()],
            [NSView(), createButtonsRow()]
        ]
    }
    
    private func createLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.alignment = .right
        return label
    }
    
    private func createButtonsRow() -> NSView {
        let saveButton = NSButton(
            title: "Save",
            target: self,
            action: #selector(onSave)
        )
        
        let testButton = NSButton(
            title: "Test",
            target: self,
            action: #selector(onTest)
        )
        
        let combineButton = NSButton(
            title: "Combine Tokens",
            target: self,
            action: #selector(onCombineTokens)
        )
        
        let stack = NSStackView(views: [saveButton, testButton, combineButton])
        stack.orientation = .horizontal
        stack.alignment = .trailing
        stack.spacing = 8
        
        return stack
    }

    // MARK: - Data Management
    
    private func loadValues() {
        let defaults = UserDefaults.standard
        
        // Load text fields
        usernameField.stringValue = defaults.string(forKey: "beeminder.username") ?? ""
        goalField.stringValue = defaults.string(forKey: "beeminder.goal") ?? ""
        tagsField.stringValue = defaults.string(forKey: "track.tags") ?? ""
        
        // Load checkboxes
        startAtLoginCheckbox.state = defaults.bool(forKey: "startAtLogin") ? .on : .off
        appleScriptModeCheckbox.state = defaults.bool(forKey: "bear.useAppleScript") ? .on : .off
        
        // Load tokens from Keychain
        loadTokensFromKeychain()
        
        // Configure sync frequency popup
        configureSyncFrequencyPopup()
    }
    
    private func loadTokensFromKeychain() {
        let keychain = KeychainStore()
        
        // Load Beeminder token
        if let beeminderToken = try? keychain.getPassword(account: "token", service: "beeminder"),
           !beeminderToken.isEmpty {
            beeminderTokenField.stringValue = beeminderToken
        } else {
            beeminderTokenField.placeholderString = "Paste your Beeminder token"
        }
        
        // Load Bear token
        if let bearToken = try? keychain.getPassword(account: "token", service: "bear"),
           !bearToken.isEmpty {
            bearTokenField.stringValue = bearToken
        } else {
            bearTokenField.placeholderString = "Paste your Bear token"
        }
    }
    
    private func configureSyncFrequencyPopup() {
        let frequency = UserDefaults.standard.integer(forKey: "sync.frequency.minutes")
        switch frequency {
        case 30: 
            syncPopup.selectItem(at: 0)
        case 120: 
            syncPopup.selectItem(at: 2)
        default: 
            syncPopup.selectItem(at: 1)
        }
    }
    
    // MARK: - Actions
    
    @objc
    private func onSave() {
        saveUserDefaults()
        saveTokensToKeychain()
        
        // Notify that settings were updated
        NotificationCenter.default.post(name: .settingsDidChange, object: nil)
        
        // Close the window after saving
        window?.close()
    }
    
    private func saveUserDefaults() {
        let defaults = UserDefaults.standard
        
        // Save text fields
        defaults.set(usernameField.stringValue, forKey: "beeminder.username")
        defaults.set(goalField.stringValue, forKey: "beeminder.goal")
        
        // Save sync frequency
        let minutes = getSelectedSyncFrequency()
        defaults.set(minutes, forKey: "sync.frequency.minutes")
        
        // Save tags
        let tagsRaw = tagsField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        defaults.set(tagsRaw, forKey: "track.tags")
        
        // Save checkboxes
        defaults.set(
            startAtLoginCheckbox.state == .on,
            forKey: "startAtLogin"
        )
        defaults.set(
            appleScriptModeCheckbox.state == .on,
            forKey: "bear.useAppleScript"
        )
        
        defaults.synchronize()
    }
    
    private func getSelectedSyncFrequency() -> Int {
        switch syncPopup.indexOfSelectedItem {
        case 0: 
            return 30
        case 2: 
            return 120
        default: 
            return 60
        }
    }
    
    private func saveTokensToKeychain() {
        let keychain = KeychainStore()
        let beeminderToken = beeminderTokenField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let bearToken = bearTokenField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Save individual tokens
        if !beeminderToken.isEmpty {
            try? keychain.setPassword(beeminderToken, account: "token", service: "beeminder")
        }
        
        if !bearToken.isEmpty {
            try? keychain.setPassword(bearToken, account: "token", service: "bear")
        }
        
        // Also write combined tokens if both are present (reduces prompts)
        if !beeminderToken.isEmpty && !bearToken.isEmpty {
            try? keychain.setCombinedTokens(beeminder: beeminderToken, bear: bearToken)
        }
    }

    // MARK: - Checkbox Actions
    
    @objc
    private func onToggleStartAtLogin(_ sender: NSButton) {
        // No-op; value is read on save
    }
    
    // MARK: - Test Connection
    
    @objc
    private func onTest() {
        guard let window = self.window else { return }
        
        let username = usernameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let goal = goalField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let beeminderToken = beeminderTokenField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let bearToken = bearTokenField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

        Task { @MainActor in
            await testBeeminderConnection(
                window: window,
                username: username,
                goal: goal,
                beeminderToken: beeminderToken,
                bearToken: bearToken
            )
        }
    }
    
    @MainActor
    private func testBeeminderConnection(
        window: NSWindow,
        username: String,
        goal: String,
        beeminderToken: String,
        bearToken: String
    ) async {
        let alert = NSAlert()
        alert.messageText = "Credentials Test"
        
        // Validate Beeminder credentials
        let beeminderValid = await validateBeeminderCredentials(
            username: username,
            goal: goal,
            token: beeminderToken
        )
        
        // Check Bear token presence
        let bearTokenPresent = !bearToken.isEmpty
        
        // Prepare alert details
        var details: [String] = []
        details.append("Beeminder: \(beeminderValid ? "✅ OK" : "⚠️ Failed (check username/token)")")
        details.append("Bear token present: \(bearTokenPresent ? "✅ Yes" : "⚠️ No")")
        
        alert.informativeText = details.joined(separator: "\n")
        alert.alertStyle = (beeminderValid && bearTokenPresent) ? .informational : .warning
        alert.addButton(withTitle: "OK")
        
        await withCheckedContinuation { continuation in
            alert.beginSheetModal(for: window) { _ in
                continuation.resume()
            }
        }
    }
    
    private func validateBeeminderCredentials(
        username: String,
        goal: String,
        token: String
    ) async -> Bool {
        guard !username.isEmpty, !goal.isEmpty, !token.isEmpty else {
            return false
        }
        
        let client = BeeminderClient(
            username: username,
            goal: goal,
            tokenProvider: { [token] in token }
        )
        
        return await client.validateCredentials()
    }
}
