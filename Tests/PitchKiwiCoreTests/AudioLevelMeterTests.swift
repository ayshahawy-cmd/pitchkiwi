import XCTest
@testable import PitchKiwiCore

final class AudioLevelMeterTests: XCTestCase {
    func testSilenceProducesZeroLevel() {
        XCTAssertEqual(AudioLevelMeter.normalized(Array(repeating: 0, count: 1_024)), 0)
    }

    func testMeterRespondsToQuietAndLoudSpeech() {
        let quiet = (0..<1_024).map { Float(sin(Double($0) * 0.12)) * 0.004 }
        let conversational = (0..<1_024).map { Float(sin(Double($0) * 0.12)) * 0.045 }
        let loud = (0..<1_024).map { Float(sin(Double($0) * 0.12)) * 0.18 }

        let quietLevel = AudioLevelMeter.normalized(quiet)
        let conversationalLevel = AudioLevelMeter.normalized(conversational)
        let loudLevel = AudioLevelMeter.normalized(loud)

        XCTAssertGreaterThan(quietLevel, 0)
        XCTAssertGreaterThan(conversationalLevel, quietLevel)
        XCTAssertGreaterThan(loudLevel, conversationalLevel)
        XCTAssertLessThanOrEqual(loudLevel, 1)
    }
}
