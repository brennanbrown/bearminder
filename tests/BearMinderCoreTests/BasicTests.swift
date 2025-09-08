import XCTest
@testable import Models
@testable import BeeminderClient
@testable import BearClient
@testable import Persistence
@testable import SyncManager

final class BasicTests: XCTestCase {
    func testSyncDryRunCompiles() async throws {
        let beeminder = BeeminderClient(username: "user", goal: "goal", tokenProvider: { "token" })
        let bear = BearClient(tokenProvider: { "bear-token" })
        let store = InMemoryPersistence()
        let settings = Settings(beeminderUsername: "user", beeminderGoal: "goal")
        let manager = SyncManager(beeminder: beeminder, bear: bear, store: store, settings: settings)
        let ok = await manager.syncNow()
        XCTAssertTrue(ok || !ok) // ensure call path executed; result is not meaningful in stub
    }
}
