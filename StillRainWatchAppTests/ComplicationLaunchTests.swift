import Foundation
import XCTest
@testable import StillRainWatchApp

final class ComplicationLaunchTests: XCTestCase {
    func testComplicationURLStartsWithComplicationSource() {
        let url = URL(string: "stillrain://start?source=complication")!

        XCTAssertEqual(
            StillRainDeepLink(url: url),
            .start(.complication)
        )
    }

    func testUnrecognizedDeepLinksAreRejected() {
        XCTAssertNil(StillRainDeepLink(url: URL(string: "other://start?source=complication")!))
        XCTAssertNil(StillRainDeepLink(url: URL(string: "stillrain://settings")!))
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
