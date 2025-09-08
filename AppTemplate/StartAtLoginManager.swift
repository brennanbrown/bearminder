import Foundation
import ServiceManagement
import Logging

enum StartAtLoginManager {
    static func apply(startAtLogin: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if startAtLogin {
                    try SMAppService.mainApp.register()
                    LOG(.info, "Enabled Start at Login via SMAppService")
                } else {
                    try SMAppService.mainApp.unregister()
                    LOG(.info, "Disabled Start at Login via SMAppService")
                }
            } catch {
                LOG(.error, "Failed to update Start at Login: \(error)")
            }
        } else {
            LOG(.warning, "Start at Login requires macOS 13+. Skipping.")
        }
    }
}
