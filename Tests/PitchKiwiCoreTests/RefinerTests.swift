import XCTest
@testable import PitchKiwiCore

final class RefinerTests: XCTestCase {
    private let refiner = DeterministicRefiner()

    func testDeveloperTermsAndCleanup() {
        let result = refiner.refine(
            text: "um set super base in dot env and use dash dash force",
            dictionary: [.init(spokenForm: "super base", writtenForm: "Supabase")],
            snippets: [],
            developerMode: true,
            mode: .dictate
        )
        XCTAssertEqual(result.text, "Set Supabase in .env and use --force")
        XCTAssertTrue(result.changes.contains { $0.kind == .filler })
        XCTAssertTrue(result.changes.contains { $0.kind == .correction })
        XCTAssertTrue(result.changes.contains { $0.kind == .developerToken })
    }

    func testExactSnippetOnly() {
        let snippet = Snippet(name: "PR checklist", trigger: "my PR checklist", expansion: "- [ ] Tests\n- [ ] Docs")
        let exact = refiner.refine(text: "my PR checklist", dictionary: [], snippets: [snippet], developerMode: true, mode: .dictate)
        XCTAssertEqual(exact.text, snippet.expansion)

        let sentence = refiner.refine(text: "please use my PR checklist later", dictionary: [], snippets: [snippet], developerMode: true, mode: .dictate)
        XCTAssertNotEqual(sentence.text, snippet.expansion)
    }

    func testRepeatedWordRemoval() {
        let result = refiner.refine(text: "the the build is ready", dictionary: [], snippets: [], developerMode: false, mode: .dictate)
        XCTAssertEqual(result.text, "The build is ready")
    }

    func testRepeatedPhraseAndWarmupRemoval() {
        let result = refiner.refine(
            text: "Yeah, so I want to I want to build a local prompt app",
            dictionary: [],
            snippets: [],
            developerMode: false,
            mode: .dictate
        )
        XCTAssertEqual(result.text, "I want to build a local prompt app")
        XCTAssertTrue(result.changes.contains { $0.kind == .filler })
        XCTAssertTrue(result.changes.contains { $0.kind == .repetition })
    }

    func testRepeatedTwoWordPhraseIsCollapsed() {
        let result = refiner.refine(
            text: "Please handle things like things like duplicate phrases",
            dictionary: [],
            snippets: [],
            developerMode: false,
            mode: .dictate
        )
        XCTAssertEqual(result.text, "Please handle things like duplicate phrases")
    }

    func testPromptModeStructuresOnlyPresentContent() {
        let result = refiner.refine(
            text: "I want to build a local dictation app. For context it runs on a Mac. Make sure it never sends audio to a server. Done when it inserts text into Cursor.",
            dictionary: [.init(spokenForm: "cursor", writtenForm: "Cursor")],
            snippets: [],
            developerMode: true,
            mode: .prompt
        )

        XCTAssertEqual(
            result.text,
            "Goal:\nBuild a local dictation app.\n\nContext:\nIt runs on a Mac.\n\nRequirements:\n- It never sends audio to a server.\n\nDone when:\n- It inserts text into Cursor."
        )
        XCTAssertTrue(result.changes.contains { $0.kind == .promptStructure })
    }

    func testResamplingProducesExpectedLength() {
        let input = [Float](repeating: 0.5, count: 48_000)
        let output = AVAudioCaptureService.resample(input, from: 48_000, to: 16_000)
        XCTAssertEqual(output.count, 16_000)
    }
}
