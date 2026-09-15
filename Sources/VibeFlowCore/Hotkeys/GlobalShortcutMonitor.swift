import AppKit
import Foundation

@MainActor
public final class GlobalShortcutMonitor {
    public enum Action {
        case pressed
        case released
        case cancel
    }

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var keyIsDown = false
    private let handler: (Action) -> Void

    public init(handler: @escaping (Action) -> Void) {
        self.handler = handler
    }

    public func start() {
        guard globalMonitor == nil, localMonitor == nil else { return }
        let mask: NSEvent.EventTypeMask = [.keyDown, .keyUp]
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            Task { @MainActor in self?.handle(event) }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            self?.handle(event)
            return event
        }
    }

    public func stop() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = nil
        localMonitor = nil
        keyIsDown = false
    }

    private func handle(_ event: NSEvent) {
        if event.type == .keyDown, event.keyCode == 53 {
            handler(.cancel)
            return
        }

        let shortcutModifiers: NSEvent.ModifierFlags = [.command, .control, .option, .shift]
        let isShortcut = event.keyCode == 49 && event.modifierFlags.intersection(shortcutModifiers) == .option
        guard isShortcut, !event.isARepeat else { return }

        if event.type == .keyDown, !keyIsDown {
            keyIsDown = true
            handler(.pressed)
        } else if event.type == .keyUp, keyIsDown {
            keyIsDown = false
            handler(.released)
        }
    }
}
