import Foundation
import XCTest
@testable import CatalystBellWatchApp

final class ComplicationLaunchTests: XCTestCase {
    func testComplicationURLStartsWithComplicationSource() {
        let url = URL(string: "catalystbell://start?source=complication")!

        XCTAssertEqual(
            CatalystBellDeepLink(url: url),
            .start(.complication)
        )
    }

    func testUnrecognizedDeepLinksAreRejected() {
        XCTAssertNil(CatalystBellDeepLink(url: URL(string: "other://start?source=complication")!))
        XCTAssertNil(CatalystBellDeepLink(url: URL(string: "catalystbell://settings")!))
    }

    func testStartRequestRunsImmediatelyFromHomeStates() {
        XCTAssertEqual(SessionState.idle.startRequestDisposition, .startImmediately)
        XCTAssertEqual(SessionState.ended.startRequestDisposition, .startImmediately)
    }

    func testStartRequestIsDeferredWhilePreviousSessionFinishes() {
        XCTAssertEqual(SessionState.stopping.startRequestDisposition, .deferUntilIdle)
        XCTAssertEqual(SessionState.saving.startRequestDisposition, .deferUntilIdle)
        XCTAssertEqual(SessionState.interrupted.startRequestDisposition, .deferUntilIdle)
    }

    func testDuplicateStartRequestIsIgnoredDuringActiveSession() {
        XCTAssertEqual(SessionState.starting.startRequestDisposition, .ignore)
        XCTAssertEqual(SessionState.active.startRequestDisposition, .ignore)
    }
}
