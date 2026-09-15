import ApplicationServices
import Foundation

public protocol AudioCapturing: Sendable {
    var levels: AsyncStream<Float> { get }
    func start() async throws
    func stop() async throws -> CapturedAudio
    func cancel() async
}

public protocol SpeechTranscribing: Sendable {
    func transcribe(_ audio: CapturedAudio, modelURL: URL, hints: [String]) async throws -> RawTranscript
}

public protocol TextRefining: Sendable {
    func refine(
        text: String,
        dictionary: [DictionaryEntry],
        snippets: [Snippet],
        developerMode: Bool,
        mode: DictationMode
    ) -> RefinementResult
}

public protocol TextInserting: Sendable {
    func captureTarget() async -> InsertionTarget
    func insert(_ text: String, into target: InsertionTarget) async throws
}

public struct InsertionTarget: @unchecked Sendable {
    public let processIdentifier: pid_t?
    public let element: AXUIElement?
    public let isSecure: Bool
    public let applicationBundleIdentifier: String?

    public init(
        processIdentifier: pid_t?,
        element: AXUIElement?,
        isSecure: Bool,
        applicationBundleIdentifier: String? = nil
    ) {
        self.processIdentifier = processIdentifier
        self.element = element
        self.isSecure = isSecure
        self.applicationBundleIdentifier = applicationBundleIdentifier
    }
}
