import XCTest
@testable import PitchKiwiCore

final class WhisperInputGateTests: XCTestCase {
    func testRejectsSilenceAndVeryShortInput() {
        XCTAssertFalse(AudioSpeechGate.hasLikelySpeech(samples: Array(repeating: 0, count: 16_000), duration: 1))
        XCTAssertFalse(AudioSpeechGate.hasLikelySpeech(samples: Array(repeating: 0.1, count: 1_600), duration: 0.1))
    }

    func testAcceptsClearlyVoicedInput() {
        let samples = (0..<16_000).map { index in
            Float(sin(Double(index) * 0.1)) * 0.08
        }
        XCTAssertTrue(AudioSpeechGate.hasLikelySpeech(samples: samples, duration: 1))
    }

    func testRejectsSilenceMarkersAndUncertainHallucinations() {
        XCTAssertFalse(TranscriptSpeechGate.accepts(
            text: "[Background noise]",
            highestNoSpeechProbability: 0.1,
            averageTokenProbability: 0.9
        ))
        XCTAssertFalse(TranscriptSpeechGate.accepts(
            text: "Thank you.",
            highestNoSpeechProbability: 0.91,
            averageTokenProbability: 0.2
        ))
    }

    func testAcceptsConfidentTranscript() {
        XCTAssertTrue(TranscriptSpeechGate.accepts(
            text: "Make the button green.",
            highestNoSpeechProbability: 0.05,
            averageTokenProbability: 0.82
        ))
    }
}
