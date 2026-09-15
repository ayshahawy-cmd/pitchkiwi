import XCTest
@testable import HormeFlowCore

@MainActor
final class LocalStoreTests: XCTestCase {
    func testNeverRetentionPersistsNoTranscriptText() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = LocalStore(directory: directory)
        store.retention = .never
        store.record(text: "PRIVATE-CANARY-TRANSCRIPT", duration: 2, fixes: 1)
        XCTAssertTrue(store.transcripts.isEmpty)

        let data = try Data(contentsOf: directory.appendingPathComponent("horme-flow.json"))
        XCTAssertNil(String(data: data, encoding: .utf8)?.range(of: "PRIVATE-CANARY-TRANSCRIPT"))
    }
}
