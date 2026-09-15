import XCTest
@testable import PitchKiwiCore

final class InsertionStrategyPolicyTests: XCTestCase {
    func testUsesGuardedPasteForPromptAndElectronApps() {
        XCTAssertTrue(InsertionStrategyPolicy.prefersGuardedPaste(bundleIdentifier: "com.openai.codex"))
        XCTAssertTrue(InsertionStrategyPolicy.prefersGuardedPaste(bundleIdentifier: "com.anthropic.claudefordesktop"))
        XCTAssertTrue(InsertionStrategyPolicy.prefersGuardedPaste(bundleIdentifier: "com.microsoft.VSCode"))
        XCTAssertTrue(InsertionStrategyPolicy.prefersGuardedPaste(bundleIdentifier: "com.todesktop.cursor"))
        XCTAssertTrue(InsertionStrategyPolicy.prefersGuardedPaste(bundleIdentifier: "com.google.Chrome.canary"))
    }

    func testKeepsDirectAccessibilityForNativeEditors() {
        XCTAssertFalse(InsertionStrategyPolicy.prefersGuardedPaste(bundleIdentifier: "com.apple.TextEdit"))
        XCTAssertFalse(InsertionStrategyPolicy.prefersGuardedPaste(bundleIdentifier: "com.apple.dt.Xcode"))
        XCTAssertFalse(InsertionStrategyPolicy.prefersGuardedPaste(bundleIdentifier: nil))
    }
}
