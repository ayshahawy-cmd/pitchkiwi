import AppKit
import AVFoundation
import Combine
import Foundation
import VibeFlowCore

@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()

    @Published private(set) var phase: DictationPhase = .idle
    @Published private(set) var statusText = "Ready"
    @Published private(set) var lastTranscript = ""
    @Published private(set) var modelURL: URL?
    @Published var scratchpad = ""

    let store = LocalStore()
    private let machine = DictationStateMachine()
    private let audio: AudioCapturing = AVAudioCaptureService()
    private let transcriber: SpeechTranscribing = WhisperTranscriber()
    private let refiner: TextRefining = DeterministicRefiner()
    private let inserter: TextInserting = AccessibilityInsertionService()
    private var insertionTarget = InsertionTarget(processIdentifier: nil, element: nil, isSecure: false)
    private var activeTask: Task<Void, Never>?

    lazy var shortcutMonitor = GlobalShortcutMonitor { [weak self] action in
        guard let self else { return }
        switch action {
        case .pressed: self.beginDictation()
        case .released: self.finishDictation()
        case .cancel: self.cancelDictation()
        }
    }

    private init() {
        modelURL = ModelManager.currentModelURL()
    }

    var microphoneAuthorized: Bool {
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    var accessibilityAuthorized: Bool {
        AccessibilityInsertionService.isAccessibilityTrusted
    }

    var modelReady: Bool { modelURL != nil }

    func beginDictation() {
        guard !phase.isActive else { return }
        activeTask?.cancel()
        activeTask = Task { await startFlow() }
    }

    func finishDictation() {
        guard phase == .listening else { return }
        activeTask?.cancel()
        activeTask = Task { await finishFlow() }
    }

    func cancelDictation() {
        guard phase.isActive else { return }
        activeTask?.cancel()
        activeTask = Task {
            try? await move(to: .cancelling)
            await audio.cancel()
            await machine.reset()
            phase = .idle
            statusText = "Cancelled"
        }
    }

    func toggleDictation() {
        phase == .listening ? finishDictation() : beginDictation()
    }

    func copyLastTranscript() {
        guard !lastTranscript.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(lastTranscript, forType: .string)
        statusText = "Copied"
    }

    func putLastInScratchpad() {
        guard !lastTranscript.isEmpty else { return }
        scratchpad = lastTranscript
        showMainWindow()
    }

    func makePromptFromLast() {
        guard !lastTranscript.isEmpty else { return }
        scratchpad = "## Objective\n\n\(lastTranscript)"
        showMainWindow()
    }

    func requestAccessibility() {
        AccessibilityInsertionService.requestAccessibilityAccess()
        objectWillChange.send()
    }

    func importModel() {
        let panel = NSOpenPanel()
        panel.title = "Import a Whisper GGML model"
        panel.message = "Choose a local .bin model. The file stays on this Mac."
        panel.allowedContentTypes = [.data]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let source = panel.url else { return }
        do {
            modelURL = try ModelManager.importModel(from: source)
            statusText = "Local model imported"
        } catch {
            statusText = error.localizedDescription
        }
    }

    func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { !($0 is NSPanel) }) {
            window.makeKeyAndOrderFront(nil)
        }
    }

    private func startFlow() async {
        if phase == .result || phase == .error {
            await machine.reset()
            phase = .idle
        }
        do {
            try await move(to: .listening)
            statusText = "Listening"
            insertionTarget = await inserter.captureTarget()
            try await audio.start()
        } catch {
            await fail(error)
        }
    }

    private func finishFlow() async {
        do {
            try await move(to: .transcribing)
            statusText = "Transcribing locally"
            let captured = try await audio.stop()
            guard let modelURL else { throw VibeFlowError.modelMissing }

            let hints = store.dictionary.filter(\.isEnabled).map(\.writtenForm)
            let raw = try await transcriber.transcribe(captured, modelURL: modelURL, hints: hints)

            try await move(to: .refining)
            statusText = "Cleaning up"
            let refined = refiner.refine(
                text: raw.text,
                dictionary: store.dictionary,
                snippets: store.snippets,
                developerMode: store.developerMode
            )
            lastTranscript = refined.text
            store.record(text: refined.text, duration: captured.duration, fixes: refined.changes.count)

            try await move(to: .inserting)
            statusText = "Inserting"
            do {
                try await inserter.insert(refined.text, into: insertionTarget)
                try await move(to: .result)
                statusText = "Inserted"
                try? await Task.sleep(for: .milliseconds(850))
                guard !Task.isCancelled else { return }
                try await move(to: .idle)
            } catch {
                try await move(to: .result)
                statusText = error.localizedDescription
                showMainWindow()
            }
        } catch is CancellationError {
            await audio.cancel()
            await machine.reset()
            phase = .idle
        } catch {
            await fail(error)
        }
    }

    private func move(to next: DictationPhase) async throws {
        try await machine.transition(to: next)
        phase = next
    }

    private func fail(_ error: Error) async {
        await audio.cancel()
        let current = await machine.phase
        if [.listening, .transcribing, .refining, .inserting].contains(current) {
            try? await machine.transition(to: .error)
        } else {
            await machine.reset()
        }
        phase = .error
        statusText = error.localizedDescription
        showMainWindow()
    }
}

