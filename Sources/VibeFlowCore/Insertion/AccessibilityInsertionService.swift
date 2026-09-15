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
        guard Self.isAccessibilityTrusted else {
            return InsertionTarget(processIdentifier: NSWorkspace.shared.frontmostApplication?.processIdentifier, element: nil, isSecure: false)
        }

        let system = AXUIElementCreateSystemWide()
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &value) == .success,
              let value else {
            return InsertionTarget(processIdentifier: NSWorkspace.shared.frontmostApplication?.processIdentifier, element: nil, isSecure: false)
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
            isSecure: role == "AXSecureTextField"
        )
    }

    public func insert(_ text: String, into target: InsertionTarget) async throws {
        guard !target.isSecure else { throw VibeFlowError.secureField }
        guard Self.isAccessibilityTrusted else { throw VibeFlowError.accessibilityDenied }
        guard let expectedPID = target.processIdentifier else {
            throw VibeFlowError.insertionFailed
        }

        let currentElement = Self.focusedElement()
        var currentPID: pid_t = 0
        if let currentElement {
            AXUIElementGetPid(currentElement, &currentPID)
        } else {
            currentPID = NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0
        }
        guard currentPID == expectedPID else { throw VibeFlowError.insertionFailed }

        if Self.isSecure(currentElement) { throw VibeFlowError.secureField }

        // Web and Electron editors may replace their Accessibility node while
        // Whisper is running. Try both the original node and the currently
        // focused node, without reading either control's contents.
        for element in [target.element, currentElement].compactMap({ $0 }) {
            if AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, text as CFTypeRef) == .success {
                return
            }
        }

        try await pasteWithRestoration(text)
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

    private func pasteWithRestoration(_ text: String) async throws {
        let pasteboard = NSPasteboard.general
        let snapshot = ClipboardSnapshot.capture(from: pasteboard)
        pasteboard.clearContents()
        guard pasteboard.setString(text, forType: .string) else {
            throw VibeFlowError.insertionFailed
        }
        let temporaryChangeCount = pasteboard.changeCount

        guard let source = CGEventSource(stateID: .combinedSessionState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else {
            snapshot.restore(to: pasteboard)
            throw VibeFlowError.insertionFailed
        }
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        do {
            try await Task.sleep(for: .milliseconds(24))
            keyDown.post(tap: .cghidEventTap)
            try await Task.sleep(for: .milliseconds(18))
            keyUp.post(tap: .cghidEventTap)

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
