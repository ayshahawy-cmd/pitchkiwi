import XCTest
@testable import PitchKiwiCore

final class FnKeyGestureRecognizerTests: XCTestCase {
    func testHoldStartsAndReleaseStopsImmediately() {
        var recognizer = FnKeyGestureRecognizer()

        XCTAssertEqual(recognizer.keyDown(at: 10), [.start])
        XCTAssertEqual(recognizer.keyUp(at: 11), [.stop])
        XCTAssertFalse(recognizer.isWaitingForSecondPress)
    }

    func testQuickSinglePressWaitsForDoublePressWindow() {
        var recognizer = FnKeyGestureRecognizer()

        XCTAssertEqual(recognizer.keyDown(at: 10), [.start])
        XCTAssertEqual(recognizer.keyUp(at: 10.1), [])
        XCTAssertTrue(recognizer.isWaitingForSecondPress)
        XCTAssertEqual(recognizer.timeout(at: 10.3), [])
        XCTAssertEqual(recognizer.timeout(at: 10.43), [.stop])
        XCTAssertFalse(recognizer.isWaitingForSecondPress)
    }

    func testDoublePressLocksHandsFreeAndNextPressStops() {
        var recognizer = FnKeyGestureRecognizer()

        XCTAssertEqual(recognizer.keyDown(at: 10), [.start])
        XCTAssertEqual(recognizer.keyUp(at: 10.08), [])
        XCTAssertEqual(recognizer.keyDown(at: 10.2), [.lockHandsFree])
        XCTAssertEqual(recognizer.keyUp(at: 10.27), [])
        XCTAssertEqual(recognizer.keyDown(at: 15), [.stop])
        XCTAssertEqual(recognizer.keyUp(at: 15.05), [])
    }

    func testResetClearsPendingGesture() {
        var recognizer = FnKeyGestureRecognizer()

        _ = recognizer.keyDown(at: 10)
        _ = recognizer.keyUp(at: 10.1)
        recognizer.reset()

        XCTAssertFalse(recognizer.isWaitingForSecondPress)
        XCTAssertEqual(recognizer.timeout(at: 11), [])
        XCTAssertEqual(recognizer.keyDown(at: 12), [.start])
    }
}
