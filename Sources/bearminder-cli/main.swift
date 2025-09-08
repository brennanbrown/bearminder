import Foundation
import Models
import BeeminderClient
import BearClient
import Persistence
import SyncManager
import Logging
import Config

@main
struct BearMinderCLI {
    static func main() async {
        // Try local/credentials.json first (gitignored), then environment variables
        let local = ConfigLoader.loadLocalCredentials()
        let envCreds = ConfigLoader.loadEnvCredentials()
        let creds = local ?? envCreds

        let haveCreds = creds != nil
        LOG(.info, haveCreds ? "Starting bearminder-cli (real POST)" : "Starting bearminder-cli (dry run: no credentials found)")

        let beeminder = BeeminderClient(username: creds?.beeminderUsername ?? "user",
                                         goal: creds?.beeminderGoal ?? "goal") { creds?.beeminderToken ?? "token" }
        let bear = BearClient { creds?.bearToken ?? "bear-token" }
        let store = InMemoryPersistence()
        let settings = Settings(beeminderUsername: creds?.beeminderUsername ?? "user",
                                beeminderGoal: creds?.beeminderGoal ?? "goal")
        let manager = SyncManager(beeminder: beeminder, bear: bear, store: store, settings: settings)
        let ok = await manager.syncNow()

        // Post the datapoint for real if credentials were provided
        if haveCreds {
            do {
                let snapshot = try store.loadDailySnapshot(for: Self.today()) ?? DailySnapshot(date: Self.today(), totalWords: 0, notesModified: 0, topTags: [], syncStatus: "pending", lastUpdated: Date())
                let comment = "📝 \(snapshot.totalWords) words across \(snapshot.notesModified) notes\n\n🐻 via Bear → Beeminder"
                let dp = BeeminderDatapoint(value: snapshot.totalWords, comment: comment, requestID: "bear-sync-\(Self.today())", timestamp: Date().timeIntervalSince1970)
                _ = try await beeminder.postDatapoint(dp, perform: true)
                print("Posted datapoint value=\(snapshot.totalWords) goal=\(creds!.beeminderGoal) user=\(creds!.beeminderUsername)")
            } catch {
                print("Error posting datapoint: \(error)")
                exit(1)
            }
        }

        print("Sync completed: \(ok ? "success" : "failure")")
    }

    private static func today() -> String {
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.timeZone = TimeZone(secondsFromGMT: 0)
        df.dateFormat = "yyyy-MM-dd"
        return df.string(from: Date())
    }
}
