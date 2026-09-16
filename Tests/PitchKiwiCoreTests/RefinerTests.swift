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

    func testStrongFillerChainAndParentheticalMarkersAreRemoved() {
        let result = refiner.refine(
            text: "Like, so, umm, ummm, I, uh, I want to, like, make the punctuation stronger period",
            dictionary: [],
            snippets: [],
            developerMode: false,
            mode: .dictate
        )

        XCTAssertEqual(result.text, "I want to make the punctuation stronger.")
        XCTAssertTrue(result.changes.contains { $0.kind == .filler })
        XCTAssertTrue(result.changes.contains { $0.kind == .repetition })
        XCTAssertTrue(result.changes.contains { $0.kind == .punctuation })
    }

    func testMoreHesitationSpellingsAreRemoved() {
        let result = refiner.refine(
            text: "Ahh, uhm, erm, let me think, ship the local build",
            dictionary: [],
            snippets: [],
            developerMode: false,
            mode: .dictate
        )

        XCTAssertEqual(result.text, "Ship the local build")
    }

    func testMeaningfulLikeAndUncertaintyArePreserved() {
        let result = refiner.refine(
            text: "I think maybe I like Swift",
            dictionary: [],
            snippets: [],
            developerMode: false,
            mode: .dictate
        )

        XCTAssertEqual(result.text, "I think maybe I like Swift")
    }

    func testSpokenPunctuationIsSpacedAndSentenceCased() {
        let result = refiner.refine(
            text: "hello comma world period this is tighter question mark yes",
            dictionary: [],
            snippets: [],
            developerMode: false,
            mode: .dictate
        )

        XCTAssertEqual(result.text, "Hello, world. This is tighter? Yes")
    }

    func testActuallyNoKeepsOnlyTheCorrectedIntent() {
        let result = refiner.refine(
            text: "I want to redesign the settings page, actually no, I want to simplify the onboarding",
            dictionary: [], snippets: [], developerMode: false, mode: .dictate
        )
        XCTAssertEqual(result.text, "I want to simplify the onboarding")
        XCTAssertTrue(result.changes.contains { $0.kind == .backtrack })
    }

    func testScratchThatBacktracksTheFalseStart() {
        let result = refiner.refine(
            text: "Build a sidebar, scratch that, build a command palette",
            dictionary: [], snippets: [], developerMode: false, mode: .dictate
        )
        XCTAssertEqual(result.text, "Build a command palette")
    }

    func testBareActuallyCorrectsComparableValuesButPreservesSemanticUse() {
        let corrected = refiner.refine(
            text: "Let's meet on Tuesday, actually Wednesday",
            dictionary: [], snippets: [], developerMode: false, mode: .dictate
        )
        XCTAssertEqual(corrected.text, "Let's meet on Wednesday")

        let semantic = refiner.refine(
            text: "I actually enjoyed the demo",
            dictionary: [], snippets: [], developerMode: false, mode: .dictate
        )
        XCTAssertEqual(semantic.text, "I actually enjoyed the demo")
    }

    func testNaturalRestatementKeepsTheLatestPhrase() {
        let result = refiner.refine(
            text: "I wanted to buy a record as a gift as a present",
            dictionary: [], snippets: [], developerMode: false, mode: .dictate
        )
        XCTAssertEqual(result.text, "I wanted to buy a record as a present")
    }

    func testSpokenNumberedListBecomesStructuredList() {
        let result = refiner.refine(
            text: "My top goals are one finish the report two send the presentation three update the issue",
            dictionary: [], snippets: [], developerMode: false, mode: .dictate
        )
        XCTAssertEqual(
            result.text,
            "My top goals are:\n1. Finish the report\n2. Send the presentation\n3. Update the issue"
        )
        XCTAssertTrue(result.changes.contains { $0.kind == .listFormatting })
    }

    func testSpokenListRepairsWhisperNumberHomophonesOnlyWithAListCue() {
        let result = refiner.refine(
            text: "The changes are one remove filler words to preserve the meaning three never press return",
            dictionary: [],
            snippets: [],
            developerMode: true,
            mode: .dictate
        )

        XCTAssertEqual(
            result.text,
            "The changes are:\n1. Remove filler words\n2. Preserve the meaning\n3. Never press return"
        )
        XCTAssertEqual(
            refiner.refine(
                text: "I want to preserve the meaning",
                dictionary: [],
                snippets: [],
                developerMode: true,
                mode: .dictate
            ).text,
            "I want to preserve the meaning"
        )
    }

    func testSpokenListPreservesTheSentenceBeforeItsHeading() {
        let result = refiner.refine(
            text: "Make the button green. new paragraph period The changes are one remove filler words to preserve meaning three never press return",
            dictionary: [],
            snippets: [],
            developerMode: true,
            mode: .dictate
        )

        XCTAssertEqual(
            result.text,
            "Make the button green.\n\nThe changes are:\n1. Remove filler words\n2. Preserve meaning\n3. Never press return"
        )
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
