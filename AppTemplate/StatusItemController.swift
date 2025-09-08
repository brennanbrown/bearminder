import AppKit
import Foundation
import SyncManager

final class StatusItemController {
    enum Action {
        case syncNow
        case openSettings
        case openBeeminder
        case quit
    }

    deinit {
        if let obs = observer { NotificationCenter.default.removeObserver(obs) }
    }

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var menu: NSMenu = NSMenu(title: "Bear → Beeminder")
    private let syncManager: SyncManager
    private let handler: (Action) -> Void
    private var observer: NSObjectProtocol?

    init(syncManager: SyncManager, handler: @escaping (Action) -> Void) {
        self.syncManager = syncManager
        self.handler = handler
    }

    func install() {
        if let button = statusItem.button {
            button.toolTip = "Bear → Beeminder Word Tracker"
            // Force title-only to guarantee visibility regardless of symbol availability
            button.title = titleForStatus()
        }
        rebuildMenu()
        statusItem.menu = menu

        observer = NotificationCenter.default.addObserver(forName: .syncStatusDidChange, object: nil, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            self.statusItem.button?.title = self.titleForStatus()
            self.rebuildMenu()
        }
    }

    func rebuildMenu() {
        menu.removeAllItems()

        // Status
        let statusTitle: String
        switch syncManager.status {
        case .idle: statusTitle = "Status: Idle ✅"
        case .syncing: statusTitle = "Status: Syncing… ⏳"
        case .error(let msg): statusTitle = "Status: Error ⚠️ - \(msg)"
        }
        let statusItem = NSMenuItem(title: statusTitle, action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)

        // Last sync line
        if let dt = syncManager.lastSyncAt {
            let df = DateFormatter()
            df.dateStyle = .none
            df.timeStyle = .short
            df.doesRelativeDateFormatting = true
            let last = df.string(from: dt)
            let lastItem = NSMenuItem(title: "Last sync: \(last)", action: nil, keyEquivalent: "")
            lastItem.isEnabled = false
            menu.addItem(lastItem)
        }

        // Next sync line
        if let next = syncManager.nextFireAt {
            let seconds = Int(max(0, next.timeIntervalSinceNow))
            let mins = seconds / 60
            let nextTitle: String
            if mins <= 0 {
                nextTitle = "Next sync: soon"
            } else {
                nextTitle = "Next sync: in \(mins)m"
            }
            let nextItem = NSMenuItem(title: nextTitle, action: nil, keyEquivalent: "")
            nextItem.isEnabled = false
            menu.addItem(nextItem)
        }

        menu.addItem(NSMenuItem.separator())

        // Actions
        menu.addItem(menuItem(title: "🔄 Sync Now", action: #selector(onSyncNow)))
        menu.addItem(menuItem(title: "⚙️ Settings", action: #selector(onOpenSettings)))
        menu.addItem(menuItem(title: "📊 Open Beeminder", action: #selector(onOpenBeeminder)))

        menu.addItem(NSMenuItem.separator())
        menu.addItem(menuItem(title: "❌ Quit", action: #selector(onQuit)))
    }

    private func menuItem(title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    @objc private func onSyncNow() { handler(.syncNow) }
    @objc private func onOpenSettings() { handler(.openSettings) }
    @objc private func onOpenBeeminder() { handler(.openBeeminder) }
    @objc private func onQuit() { handler(.quit) }

    private func titleForStatus() -> String {
        let dot: String
        switch syncManager.status {
        case .idle: dot = "🟢"
        case .syncing: dot = "🟡"
        case .error: dot = "🔴"
        }
        return "🐻" + dot
    }
}
