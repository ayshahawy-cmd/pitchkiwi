import AppKit
import ApplicationServices
import Foundation

public final class AccessibilityInsertionService: TextInserting, @unchecked Sendable {
    public init() {}

    public static var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    public static func requestAccessibilityAccess() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    public static func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }

    public func captureTarget() async -> InsertionTarget {
        let frontmostApplication = NSWorkspace.shared.frontmostApplication
        guard Self.isAccessibilityTrusted else {
            return InsertionTarget(
                processIdentifier: frontmostApplication?.processIdentifier,
                element: nil,
                isSecure: false,
                applicationBundleIdentifier: frontmostApplication?.bundleIdentifier
            )
        }

        let system = AXUIElementCreateSystemWide()
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &value) == .success,
              let value else {
            return InsertionTarget(
                processIdentifier: frontmostApplication?.processIdentifier,
                element: nil,
                isSecure: false,
                applicationBundleIdentifier: frontmostApplication?.bundleIdentifier
            )
        }

        let element = value as! AXUIElement
        var pid: pid_t = 0
        AXUIElementGetPid(element, &pid)
        var roleValue: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleValue)
        let role = roleValue as? String
        return InsertionTarget(
            processIdentifier: pid,
            element: element,
            isSecure: role == "AXSecureTextField",
            applicationBundleIdentifier: NSRunningApplication(processIdentifier: pid)?.bundleIdentifier
        )
    }

    public func insert(_ text: String, into target: InsertionTarget) async throws {
        guard !target.isSecure else { throw PitchKiwiError.secureField }
        guard Self.isAccessibilityTrusted else { throw PitchKiwiError.accessibilityDenied }
        guard let expectedPID = target.processIdentifier else {
            throw PitchKiwiError.insertionFailed
        }

        let currentElement = Self.focusedElement()
        var currentPID: pid_t = 0
        if let currentElement {
            AXUIElementGetPid(currentElement, &currentPID)
        } else {
            currentPID = NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0
        }
        guard currentPID == expectedPID else { throw PitchKiwiError.insertionFailed }

        if Self.isSecure(currentElement) { throw PitchKiwiError.secureField }

        // Chromium and Electron editors can return AX success without changing
        // their document. Use the guarded paste path for those apps instead of
        // accepting that false positive. The paste is addressed to the captured
        // process and never includes Return/Enter.
        if InsertionStrategyPolicy.prefersGuardedPaste(
            bundleIdentifier: target.applicationBundleIdentifier
        ) {
            try await pasteWithRestoration(text, targetPID: expectedPID)
            return
        }

        // Web and Electron editors may replace their Accessibility node while
        // Whisper is running. Try both the original node and the currently
        // focused node, without reading either control's contents.
        for element in [target.element, currentElement].compactMap({ $0 }) {
            if AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, text as CFTypeRef) == .success {
                return
            }
        }

        try await pasteWithRestoration(text, targetPID: expectedPID)
    }

    public func contextHints(around target: InsertionTarget, limit: Int = 40) async -> [String] {
        guard limit > 0,
              Self.isAccessibilityTrusted,
              !target.isSecure,
              let element = target.element,
              !Self.isSecure(element) else { return [] }

        var selectedValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &selectedValue
        ) == .success,
        let selectedValue,
        CFGetTypeID(selectedValue) == AXValueGetTypeID() else { return [] }

        var selectedRange = CFRange()
        guard AXValueGetValue(selectedValue as! AXValue, .cfRange, &selectedRange) else { return [] }
        let location = max(0, selectedRange.location)
        let start = max(0, location - 1_000)
        var characterCountValue: CFTypeRef?
        let characterCount: Int
        if AXUIElementCopyAttributeValue(
            element,
            kAXNumberOfCharactersAttribute as CFString,
            &characterCountValue
        ) == .success,
        let number = characterCountValue as? NSNumber {
            characterCount = number.intValue
        } else {
            characterCount = location
        }
        var boundedRange = CFRange(
            location: start,
            length: max(0, min(2_000, characterCount - start))
        )
        guard boundedRange.length > 0 else { return [] }
        guard let rangeValue = AXValueCreate(.cfRange, &boundedRange) else { return [] }

        var contextValue: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXStringForRangeParameterizedAttribute as CFString,
            rangeValue,
            &contextValue
        ) == .success,
        let context = contextValue as? String else { return [] }

        return ContextHintExtractor.extract(from: context, limit: limit)
    }

    private static func focusedElement() -> AXUIElement? {
        let system = AXUIElementCreateSystemWide()
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &value) == .success,
              let value else { return nil }
        return (value as! AXUIElement)
    }

    private static func isSecure(_ element: AXUIElement?) -> Bool {
        guard let element else { return false }
        var roleValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleValue) == .success else {
            return false
        }
        return (roleValue as? String) == "AXSecureTextField"
    }

    private func pasteWithRestoration(_ text: String, targetPID: pid_t) async throws {
        let pasteboard = NSPasteboard.general
        let snapshot = ClipboardSnapshot.capture(from: pasteboard)
        pasteboard.clearContents()
        guard pasteboard.setString(text, forType: .string) else {
            throw PitchKiwiError.insertionFailed
        }
        let temporaryChangeCount = pasteboard.changeCount

        guard let source = CGEventSource(stateID: .combinedSessionState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else {
            snapshot.restore(to: pasteboard)
            throw PitchKiwiError.insertionFailed
        }
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        do {
            try await Task.sleep(for: .milliseconds(24))
            keyDown.postToPid(targetPID)
            try await Task.sleep(for: .milliseconds(18))
            keyUp.postToPid(targetPID)

            // Chromium/Electron editors can consume synthetic paste events on
            // a later run-loop turn. Keep the lease alive before restoration.
            try await Task.sleep(for: .milliseconds(650))
        } catch {
            if pasteboard.changeCount == temporaryChangeCount {
                snapshot.restore(to: pasteboard)
            }
            throw error
        }
        if pasteboard.changeCount == temporaryChangeCount {
            snapshot.restore(to: pasteboard)
        }
    }
}

enum InsertionStrategyPolicy {
    static func prefersGuardedPaste(bundleIdentifier: String?) -> Bool {
        guard let identifier = bundleIdentifier?.lowercased(), !identifier.isEmpty else {
            return false
        }

        let exactIdentifiers: Set<String> = [
            "com.openai.codex",
            "com.anthropic.claudefordesktop",
            "com.microsoft.vscode",
            "company.thebrowser.browser",
            "org.mozilla.firefox",
        ]
        if exactIdentifiers.contains(identifier) { return true }

        let webOrElectronPrefixes = [
            "com.google.chrome",
            "com.microsoft.edgemac",
            "com.apple.safari",
            "com.brave.browser",
            "com.electron.",
            "com.todesktop.",
        ]
        return webOrElectronPrefixes.contains { identifier.hasPrefix($0) }
            || identifier.contains("cursor")
            || identifier.contains("windsurf")
    }
}

enum ContextHintExtractor {
    static func extract(from context: String, limit: Int) -> [String] {
        guard limit > 0,
              let regex = try? NSRegularExpression(
                pattern: #"(?<![\p{L}\p{N}_])[\p{L}][\p{L}\p{N}_.:@/\-]{1,63}(?![\p{L}\p{N}_])"#
              ) else { return [] }

        let ordinaryWords: Set<String> = [
            "this", "that", "with", "from", "have", "will", "your", "what", "when",
            "where", "which", "into", "about", "then", "than", "just", "make", "build",
            "open", "close", "create", "update", "remove", "please", "should", "would",
        ]
        var seen: Set<String> = []
        var hints: [String] = []
        for match in regex.matches(in: context, range: NSRange(context.startIndex..., in: context)) {
            guard let range = Range(match.range, in: context) else { continue }
            let token = String(context[range])
            let lowered = token.lowercased()
            let hasDeveloperShape = token.contains(where: { "_./@-".contains($0) })
                || token.dropFirst().contains(where: \Character.isUppercase)
                || token.first?.isUppercase == true
            guard hasDeveloperShape, !ordinaryWords.contains(lowered), seen.insert(lowered).inserted else { continue }
            hints.append(token)
            if hints.count == limit { break }
        }
        return hints
    }
}

private struct ClipboardSnapshot {
    struct Item {
        let representations: [(NSPasteboard.PasteboardType, Data)]
    }

    let items: [Item]

    static func capture(from pasteboard: NSPasteboard) -> ClipboardSnapshot {
        let items = (pasteboard.pasteboardItems ?? []).map { item in
            Item(representations: item.types.compactMap { type in
                item.data(forType: type).map { (type, $0) }
            })
        }
        return ClipboardSnapshot(items: items)
    }

    func restore(to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        guard !items.isEmpty else { return }
        let restored = items.map { snapshot -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in snapshot.representations {
                item.setData(data, forType: type)
            }
            return item
        }
        pasteboard.writeObjects(restored)
    }
}
