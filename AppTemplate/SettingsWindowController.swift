import AppKit
import KeychainSupport

final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private var usernameField = NSTextField(string: "")
    private var goalField = NSTextField(string: "")
    private var syncPopup = NSPopUpButton()
    private var beeminderTokenField = NSSecureTextField(string: "")
    private var bearTokenField = NSSecureTextField(string: "")

    convenience init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 220),
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
            [label("Sync Frequency:"), syncPopup],
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
        window?.close()
    }

    @objc private func onTest() {
        let alert = NSAlert()
        alert.messageText = "Test"
        alert.informativeText = "This would validate your tokens and connectivity in the full app."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.beginSheetModal(for: self.window!) { _ in }
    }
}
