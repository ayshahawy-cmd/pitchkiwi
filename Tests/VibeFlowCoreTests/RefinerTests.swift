import XCTest
@testable import VibeFlowCore

final class RefinerTests: XCTestCase {
    private let refiner = DeterministicRefiner()

    func testDeveloperTermsAndCleanup() {
        let result = refiner.refine(
            text: "um set super base in dot env and use dash dash force",
            dictionary: [.init(spokenForm: "super base", writtenForm: "Supabase")],
            snippets: [],
            developerMode: true
        )
        XCTAssertEqual(result.text, "Set Supabase in .env and use --force")
        XCTAssertTrue(result.changes.contains { $0.kind == .filler })
        XCTAssertTrue(result.changes.contains { $0.kind == .correction })
        XCTAssertTrue(result.changes.contains { $0.kind == .developerToken })
    }

    func testExactSnippetOnly() {
        let snippet = Snippet(name: "PR checklist", trigger: "my PR checklist", expansion: "- [ ] Tests\n- [ ] Docs")
        let exact = refiner.refine(text: "my PR checklist", dictionary: [], snippets: [snippet], developerMode: true)
        XCTAssertEqual(exact.text, snippet.expansion)

        let sentence = refiner.refine(text: "please use my PR checklist later", dictionary: [], snippets: [snippet], developerMode: true)
        XCTAssertNotEqual(sentence.text, snippet.expansion)
    }

    func testRepeatedWordRemoval() {
        let result = refiner.refine(text: "the the build is ready", dictionary: [], snippets: [], developerMode: false)
        XCTAssertEqual(result.text, "The build is ready")
    }

    func testResamplingProducesExpectedLength() {
        let input = [Float](repeating: 0.5, count: 48_000)
        let output = AVAudioCaptureService.resample(input, from: 48_000, to: 16_000)
        XCTAssertEqual(output.count, 16_000)
    }
}

