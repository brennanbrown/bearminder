import Foundation
import Logging

public struct Credentials: Codable, Equatable {
    public let beeminderUsername: String
    public let beeminderGoal: String
    public let beeminderToken: String
    public let bearToken: String
}

public enum ConfigLoader {
    /// Attempts to load credentials from ./local/credentials.json (gitignored).
    /// If not found or decoding fails, returns nil.
    public static func loadLocalCredentials(packageRoot: URL? = nil) -> Credentials? {
        let fm = FileManager.default
        let root: URL
        if let packageRoot = packageRoot {
            root = packageRoot
        } else {
            root = URL(fileURLWithPath: fm.currentDirectoryPath)
        }
        let path = root.appendingPathComponent("local/credentials.json")
        guard fm.fileExists(atPath: path.path) else { return nil }
        do {
            let data = try Data(contentsOf: path)
            let creds = try JSONDecoder().decode(Credentials.self, from: data)
            return creds
        } catch {
            LOG(.warning, "Failed to load local credentials: \(error)")
            return nil
        }
    }

    /// Loads credentials from environment variables; returns nil if any required value missing.
    public static func loadEnvCredentials(env: [String: String] = ProcessInfo.processInfo.environment) -> Credentials? {
        guard
            let user = env["BEEMINDER_USERNAME"], !user.isEmpty,
            let goal = env["BEEMINDER_GOAL"], !goal.isEmpty,
            let token = env["BEEMINDER_TOKEN"], !token.isEmpty,
            let bear = env["BEAR_TOKEN"], !bear.isEmpty
        else { return nil }
        return Credentials(beeminderUsername: user, beeminderGoal: goal, beeminderToken: token, bearToken: bear)
    }
}
