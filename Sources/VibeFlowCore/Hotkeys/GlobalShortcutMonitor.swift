import AppKit
import Foundation

@MainActor
public final class GlobalShortcutMonitor {
    public enum Action {
        case pressed
        case released
        case handsFree
        case cancel
    }

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var functionKeyIsDown = false
    private var recognizer = FnKeyGestureRecognizer()
    private var pendingRelease: Task<Void, Never>?
    private let handler: (Action) -> Void

    public init(handler: @escaping (Action) -> Void) {
        self.handler = handler
    }

    public func start() {
        guard globalMonitor == nil, localMonitor == nil else { return }
        let mask: NSEvent.EventTypeMask = [.keyDown, .flagsChanged]
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
        resetInteraction()
    }

    public func resetInteraction() {
        pendingRelease?.cancel()
        pendingRelease = nil
        functionKeyIsDown = false
        recognizer.reset()
    }

    private func handle(_ event: NSEvent) {
        if event.type == .keyDown, event.keyCode == 53 {
            resetInteraction()
            handler(.cancel)
            return
        }

        guard event.type == .flagsChanged, event.keyCode == 63 else { return }
        let isDown = event.modifierFlags.contains(.function)
        guard isDown != functionKeyIsDown else { return }
        functionKeyIsDown = isDown

        pendingRelease?.cancel()
        pendingRelease = nil

        let commands = isDown
            ? recognizer.keyDown(at: event.timestamp)
            : recognizer.keyUp(at: event.timestamp)
        emit(commands)

        if recognizer.isWaitingForSecondPress {
            pendingRelease = Task { [weak self] in
                do {
                    try await Task.sleep(for: .milliseconds(330))
                } catch {
                    return
                }
                guard let self else { return }
                self.pendingRelease = nil
                self.emit(self.recognizer.timeout(at: ProcessInfo.processInfo.systemUptime))
            }
        }
    }

    private func emit(_ commands: [FnGestureCommand]) {
        for command in commands {
            switch command {
            case .start: handler(.pressed)
            case .stop: handler(.released)
            case .lockHandsFree: handler(.handsFree)
            }
        }
    }
}
