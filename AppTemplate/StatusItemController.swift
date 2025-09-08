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

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var menu: NSMenu = NSMenu(title: "Bear → Beeminder")
    private let syncManager: SyncManager
    private let handler: (Action) -> Void

    init(syncManager: SyncManager, handler: @escaping (Action) -> Void) {
        self.syncManager = syncManager
        self.handler = handler
    }

    func install() {
        if let button = statusItem.button {
            button.toolTip = "Bear → Beeminder Word Tracker"
            // Force title-only to guarantee visibility regardless of symbol availability
            button.title = "🐻"
        }
        rebuildMenu()
        statusItem.menu = menu
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
}
