import XCTest
@testable import PitchKiwiCore

final class ContextHintExtractorTests: XCTestCase {
    func testExtractsOnlyBoundedDeveloperAndNameHints() {
        let hints = ContextHintExtractor.extract(
            from: "Open AuthService.swift and connect refresh_token to Supabase in src/auth/session.ts",
            limit: 4
        )

        XCTAssertEqual(hints, ["AuthService.swift", "refresh_token", "Supabase", "src/auth/session.ts"])
    }

    func testDeduplicatesCaseInsensitivelyAndHonorsLimit() {
        let hints = ContextHintExtractor.extract(from: "Codex codex PitchKiwi OtherName", limit: 2)
        XCTAssertEqual(hints, ["Codex", "PitchKiwi"])
    }
}
