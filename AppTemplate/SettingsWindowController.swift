import AppKit
import KeychainSupport

final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private var usernameField = NSTextField(string: "")
    private var goalField = NSTextField(string: "")
    private var syncPopup = NSPopUpButton()
    private var beeminderTokenField = NSSecureTextField(string: "")
    private var bearTokenField = NSSecureTextField(string: "")
    private var tagsField = NSTextField(string: "")
    private var startAtLoginCheckbox = NSButton(checkboxWithTitle: "Start at login", target: nil, action: nil)

    convenience init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 300),
                              styleMask: [.titled, .closable],
                              backing: .buffered,
                              defer: false)
        window.title = "Bear → Beeminder Settings"
        self.init(window: window)
        self.window?.delegate = self
        setupUI()
        loadValues()
    }

    func show() {
        guard let window = self.window else { return }
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func setupUI() {
        guard let content = window?.contentView else { return }

        let grid = NSGridView(views: [
            [label("Beeminder Username:"), usernameField],
            [label("Goal Name:"), goalField],
            [label("Beeminder API Token:"), beeminderTokenField],
            [label("Bear API Token:"), bearTokenField],
            [label("Track only these tags (optional):"), tagsField],
            [label("Sync Frequency:"), syncPopup],
            [startAtLoginCheckbox, NSView()],
            [NSView(), buttonsRow()]
        ])
        grid.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(grid)

        NSLayoutConstraint.activate([
            grid.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            grid.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            grid.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            grid.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -20)
        ])

        syncPopup.addItems(withTitles: ["Every 30 min", "Every hour", "Every 2 hours"]) // values: 30, 60, 120
        startAtLoginCheckbox.target = self
        startAtLoginCheckbox.action = #selector(onToggleStartAtLogin(_:))
    }

    private func label(_ text: String) -> NSTextField {
        let l = NSTextField(labelWithString: text)
        l.alignment = .right
        return l
    }

    private func buttonsRow() -> NSView {
        let save = NSButton(title: "Save", target: self, action: #selector(onSave))
        let test = NSButton(title: "Test", target: self, action: #selector(onTest))
        let stack = NSStackView(views: [save, test])
        stack.orientation = .horizontal
        stack.alignment = .trailing
        stack.spacing = 8
        return stack
    }

    private func loadValues() {
        let d = UserDefaults.standard
        usernameField.stringValue = d.string(forKey: "beeminder.username") ?? ""
        goalField.stringValue = d.string(forKey: "beeminder.goal") ?? ""
        tagsField.stringValue = d.string(forKey: "track.tags") ?? ""
        startAtLoginCheckbox.state = d.bool(forKey: "startAtLogin") ? .on : .off
        // Load Beeminder token
        let keychain = KeychainStore()
        if let bm = try? keychain.getPassword(account: "token", service: "beeminder"), !bm.isEmpty {
            beeminderTokenField.stringValue = bm
        } else {
            beeminderTokenField.placeholderString = "Paste your Beeminder token"
        }
        // Load Bear token from Keychain (masked field)
        if let token = try? keychain.getPassword(account: "token", service: "bear"), !token.isEmpty {
            bearTokenField.stringValue = token
        } else {
            bearTokenField.placeholderString = "Paste your Bear token"
        }
        let freq = d.integer(forKey: "sync.frequency.minutes")
        switch freq {
        case 30: syncPopup.selectItem(at: 0)
        case 120: syncPopup.selectItem(at: 2)
        default: syncPopup.selectItem(at: 1)
        }
    }

    @objc private func onSave() {
        let d = UserDefaults.standard
        d.set(usernameField.stringValue, forKey: "beeminder.username")
        d.set(goalField.stringValue, forKey: "beeminder.goal")
        let minutes: Int
        switch syncPopup.indexOfSelectedItem {
        case 0: minutes = 30
        case 2: minutes = 120
        default: minutes = 60
        }
        d.set(minutes, forKey: "sync.frequency.minutes")
        let tagsRaw = tagsField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        d.set(tagsRaw, forKey: "track.tags")
        let startAtLogin = (startAtLoginCheckbox.state == .on)
        d.set(startAtLogin, forKey: "startAtLogin")
        d.synchronize()

        // Save Beeminder token to Keychain if provided
        let bm = beeminderTokenField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if !bm.isEmpty {
            let keychain = KeychainStore()
            try? keychain.setPassword(bm, account: "token", service: "beeminder")
        }

        // Save Bear token to Keychain if provided
        let token = bearTokenField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if !token.isEmpty {
            let keychain = KeychainStore()
            try? keychain.setPassword(token, account: "token", service: "bear")
        }
        // Notify app to apply settings immediately
        let tags: [String]? = tagsRaw.isEmpty ? nil : tagsRaw.split{ $0 == "," || $0 == " " }.map{ String($0).trimmingCharacters(in: .whitespaces) }.filter{ !$0.isEmpty }
        NotificationCenter.default.post(name: .settingsDidSave, object: nil, userInfo: [
            "minutes": minutes,
            "tags": tags as Any,
            "startAtLogin": startAtLogin
        ])
        window?.close()
    }

    @objc private func onToggleStartAtLogin(_ sender: NSButton) {
        // no-op; value is read on save
    }

    @objc private func onTest() {
        guard let window = self.window else { return }
        let username = usernameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let goal = goalField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let bmToken = beeminderTokenField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let bearToken = bearTokenField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

        Task { @MainActor in
            // Validate Beeminder via a lightweight GET
            let client = BeeminderClient(username: username, goal: goal, tokenProvider: { bmToken })
            let bmOK = await client.validateCredentials()
            let bearOK = !bearToken.isEmpty // basic presence check for now

            let alert = NSAlert()
            alert.messageText = "Credentials Test"
            var details: [String] = []
            details.append("Beeminder: \(bmOK ? "✅ OK" : "⚠️ Failed (check username/token)")")
            details.append("Bear token present: \(bearOK ? "✅ Yes" : "⚠️ No")")
            alert.informativeText = details.joined(separator: "\n")
            alert.alertStyle = (bmOK && bearOK) ? .informational : .warning
            alert.addButton(withTitle: "OK")
            alert.beginSheetModal(for: window) { _ in }
        }
    }
}
