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
        guard let expectedPID = target.processIdentifier,
              NSWorkspace.shared.frontmostApplication?.processIdentifier == expectedPID else {
            throw VibeFlowError.insertionFailed
        }

        if let element = target.element,
           AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, text as CFTypeRef) == .success {
            return
        }

        guard Self.isAccessibilityTrusted else { throw VibeFlowError.accessibilityDenied }
        try await pasteWithRestoration(text)
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
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)

        try await Task.sleep(for: .milliseconds(160))
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
