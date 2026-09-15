import Foundation

public enum DictationPhase: String, Codable, CaseIterable, Sendable {
    case idle
    case listening
    case transcribing
    case refining
    case inserting
    case cancelling
    case result
    case error

    public var isActive: Bool {
        ![.idle, .result, .error].contains(self)
    }
}

public enum VibeFlowError: LocalizedError, Equatable, Sendable {
    case invalidTransition(from: DictationPhase, to: DictationPhase)
    case microphonePermissionDenied
    case microphoneUnavailable
    case noSpeech
    case modelMissing
    case modelInvalid
    case transcriptionFailed
    case accessibilityDenied
    case secureField
    case insertionFailed

    public var errorDescription: String? {
        switch self {
        case let .invalidTransition(from, to): "Invalid dictation transition: \(from.rawValue) → \(to.rawValue)."
        case .microphonePermissionDenied: "Microphone access is off. Enable it in System Settings."
        case .microphoneUnavailable: "The selected microphone is unavailable."
        case .noSpeech: "No speech was detected."
        case .modelMissing: "Install or import a local Whisper model first."
        case .modelInvalid: "The selected file is not a valid Whisper GGML model."
        case .transcriptionFailed: "Local transcription failed."
        case .accessibilityDenied: "Accessibility access is off. Your text is ready to copy."
        case .secureField: "VibeFlow does not insert into secure text fields."
        case .insertionFailed: "The focused app did not accept the text."
        }
    }
}

public struct CapturedAudio: Sendable {
    public let samples: [Float]
    public let sampleRate: Double
    public let duration: TimeInterval

    public init(samples: [Float], sampleRate: Double, duration: TimeInterval) {
        self.samples = samples
        self.sampleRate = sampleRate
        self.duration = duration
    }
}

public struct RawTranscript: Sendable, Equatable {
    public let text: String

    public init(text: String) {
        self.text = text
    }
}

public struct RefinementChange: Codable, Identifiable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case filler
        case repetition
        case punctuation
        case correction
        case snippet
        case developerToken
    }

    public let id: UUID
    public let kind: Kind

    public init(id: UUID = UUID(), kind: Kind) {
        self.id = id
        self.kind = kind
    }
}

public struct RefinementResult: Sendable, Equatable {
    public let text: String
    public let changes: [RefinementChange]

    public init(text: String, changes: [RefinementChange]) {
        self.text = text
        self.changes = changes
    }
}

public struct DictionaryEntry: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var spokenForm: String
    public var writtenForm: String
    public var isEnabled: Bool

    public init(id: UUID = UUID(), spokenForm: String, writtenForm: String, isEnabled: Bool = true) {
        self.id = id
        self.spokenForm = spokenForm
        self.writtenForm = writtenForm
        self.isEnabled = isEnabled
    }
}

public struct Snippet: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public var trigger: String
    public var expansion: String
    public var isEnabled: Bool

    public init(id: UUID = UUID(), name: String, trigger: String, expansion: String, isEnabled: Bool = true) {
        self.id = id
        self.name = name
        self.trigger = trigger
        self.expansion = expansion
        self.isEnabled = isEnabled
    }
}

public struct TranscriptRecord: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public let createdAt: Date
    public let text: String
    public let wordCount: Int
    public let duration: TimeInterval

    public init(id: UUID = UUID(), createdAt: Date = Date(), text: String, duration: TimeInterval) {
        self.id = id
        self.createdAt = createdAt
        self.text = text
        self.wordCount = text.split(whereSeparator: \.isWhitespace).count
        self.duration = duration
    }
}

public enum HistoryRetention: String, Codable, CaseIterable, Sendable, Identifiable {
    case never
    case oneDay
    case sevenDays
    case thirtyDays
    case forever

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .never: "Never"
        case .oneDay: "24 hours"
        case .sevenDays: "7 days"
        case .thirtyDays: "30 days"
        case .forever: "Forever"
        }
    }

    public var cutoff: Date? {
        let days: Int
        switch self {
        case .never: return Date()
        case .oneDay: days = 1
        case .sevenDays: days = 7
        case .thirtyDays: days = 30
        case .forever: return nil
        }
        return Calendar.current.date(byAdding: .day, value: -days, to: Date())
    }
}

public struct UsageMetrics: Codable, Equatable, Sendable {
    public var totalWords = 0
    public var dictations = 0
    public var captureSeconds: TimeInterval = 0
    public var fixes = 0

    public init() {}

    public var wordsPerMinute: Int {
        guard captureSeconds > 0 else { return 0 }
        return Int((Double(totalWords) / captureSeconds) * 60)
    }
}
