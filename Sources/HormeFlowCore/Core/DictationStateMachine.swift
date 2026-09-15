import Foundation

public actor DictationStateMachine {
    public private(set) var phase: DictationPhase = .idle

    public init() {}

    public func transition(to next: DictationPhase) throws {
        guard Self.allowed[phase, default: []].contains(next) else {
            throw HormeFlowError.invalidTransition(from: phase, to: next)
        }
        phase = next
    }

    public func reset() {
        phase = .idle
    }

    private static let allowed: [DictationPhase: Set<DictationPhase>] = [
        .idle: [.listening],
        .listening: [.transcribing, .cancelling, .error],
        .transcribing: [.refining, .cancelling, .error],
        .refining: [.inserting, .result, .cancelling, .error],
        .inserting: [.idle, .result, .error],
        .cancelling: [.idle],
        .result: [.idle, .inserting, .listening],
        .error: [.idle, .listening],
    ]
}

