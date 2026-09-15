import XCTest
@testable import PitchKiwiCore

final class StateMachineTests: XCTestCase {
    func testHappyPath() async throws {
        let machine = DictationStateMachine()
        try await machine.transition(to: .listening)
        try await machine.transition(to: .transcribing)
        try await machine.transition(to: .refining)
        try await machine.transition(to: .inserting)
        try await machine.transition(to: .result)
        try await machine.transition(to: .idle)
        let phase = await machine.phase
        XCTAssertEqual(phase, .idle)
    }

    func testInvalidTransitionIsRejected() async {
        let machine = DictationStateMachine()
        do {
            try await machine.transition(to: .inserting)
            XCTFail("Expected transition to fail")
        } catch let error as PitchKiwiError {
            XCTAssertEqual(error, .invalidTransition(from: .idle, to: .inserting))
        } catch {
            XCTFail("Unexpected error")
        }
    }
}

