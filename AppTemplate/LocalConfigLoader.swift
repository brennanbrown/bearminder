import Foundation
import Config
import KeychainSupport

/// Loads local development credentials from local/credentials.json (gitignored)
/// and seeds UserDefaults + Keychain on first launch.
/// Safe to call on every launch; it only writes if missing.
enum LocalConfigLoader {
    static func seedIfNeeded(userDefaults: UserDefaults = .standard, keychain: SecureStoreType = KeychainStore()) {
        // If username/goal already present, assume app has been configured.
        let hasUsername = !(userDefaults.string(forKey: "beeminder.username") ?? "").isEmpty
        let hasGoal = !(userDefaults.string(forKey: "beeminder.goal") ?? "").isEmpty
        let hasBeeminderToken = (try? keychain.getPassword(account: "token", service: "beeminder")).map { !$0.isEmpty } ?? false
        let hasBearToken = (try? keychain.getPassword(account: "token", service: "bear")).map { !$0.isEmpty } ?? false
        if hasUsername && hasGoal && hasBeeminderToken && hasBearToken { return }

        guard let creds = ConfigLoader.loadLocalCredentials() else { return }

        if !hasUsername { userDefaults.set(creds.beeminderUsername, forKey: "beeminder.username") }
        if !hasGoal { userDefaults.set(creds.beeminderGoal, forKey: "beeminder.goal") }
        if !hasBeeminderToken {
            try? keychain.setPassword(creds.beeminderToken, account: "token", service: "beeminder")
        }
        if !hasBearToken {
            try? keychain.setPassword(creds.bearToken, account: "token", service: "bear")
        }
        userDefaults.synchronize()
    }
}
