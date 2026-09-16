import XCTest
@testable import PitchKiwiCore

@MainActor
final class LocalStoreTests: XCTestCase {
    func testNeverRetentionPersistsNoTranscriptText() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = LocalStore(directory: directory)
        store.retention = .never
        store.record(text: "PRIVATE-CANARY-TRANSCRIPT", duration: 2, changes: [.init(kind: .filler)], mode: .dictate)
        XCTAssertTrue(store.transcripts.isEmpty)

        let data = try Data(contentsOf: directory.appendingPathComponent("pitchkiwi.json"))
        XCTAssertNil(String(data: data, encoding: .utf8)?.range(of: "PRIVATE-CANARY-TRANSCRIPT"))
    }

    func testPromptAndDeveloperCountersPersist() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = LocalStore(directory: directory)
        store.record(
            text: "Goal:\nBuild with Supabase.",
            duration: 3,
            changes: [.init(kind: .correction), .init(kind: .promptStructure)],
            mode: .prompt
        )

        XCTAssertEqual(store.metrics.prompts, 1)
        XCTAssertEqual(store.metrics.developerFixes, 1)
    }

    func testVibeFlowDataMigratesAndReceivesDeveloperSeedsOnce() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let legacy = """
        {
          "contextEnabled" : false,
          "developerMode" : true,
          "dictionary" : [{"id":"00000000-0000-0000-0000-000000000001","isEnabled":true,"spokenForm":"my tool","writtenForm":"MyTool"}],
          "metrics" : {"captureSeconds":0,"dictations":0,"fixes":0,"totalWords":0},
          "retention" : "never",
          "snippets" : [],
          "transcripts" : []
        }
        """
        try Data(legacy.utf8).write(to: directory.appendingPathComponent("vibeflow.json"))

        let store = LocalStore(directory: directory)

        XCTAssertTrue(store.dictionary.contains { $0.writtenForm == "MyTool" })
        XCTAssertTrue(store.dictionary.contains { $0.writtenForm == "Claude Code" })
        XCTAssertTrue(store.dictionary.contains { $0.writtenForm == "useEffect" })
        XCTAssertEqual(store.dictationMode, .dictate)
        XCTAssertEqual(store.promptLength, .medium)
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.appendingPathComponent("pitchkiwi.json").path))
    }

    func testPromptLengthPersistsLocally() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = LocalStore(directory: directory)
        store.promptLength = .detailed

        let reloaded = LocalStore(directory: directory)
        XCTAssertEqual(reloaded.promptLength, .detailed)
    }
}
