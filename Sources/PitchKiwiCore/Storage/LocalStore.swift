import Combine
import Foundation

@MainActor
public final class LocalStore: ObservableObject {
    @Published public var dictionary: [DictionaryEntry] { didSet { save() } }
    @Published public var snippets: [Snippet] { didSet { save() } }
    @Published public var transcripts: [TranscriptRecord] { didSet { save() } }
    @Published public var metrics: UsageMetrics { didSet { save() } }
    @Published public var retention: HistoryRetention { didSet { prune(); save() } }
    @Published public var developerMode: Bool { didSet { save() } }
    @Published public var contextEnabled: Bool { didSet { save() } }
    @Published public var dictationMode: DictationMode { didSet { save() } }
    @Published public var promptLength: PromptLength { didSet { save() } }

    private let fileURL: URL
    private var isLoading = true
    private var dictionarySeedVersion: Int

    public init(directory: URL? = nil) {
        let root = directory ?? ModelManager.appSupportDirectory()
        let newFile = root.appendingPathComponent("pitchkiwi.json")
        let legacyFile = root.appendingPathComponent("vibeflow.json")
        if !FileManager.default.fileExists(atPath: newFile.path),
           FileManager.default.fileExists(atPath: legacyFile.path) {
            try? FileManager.default.moveItem(at: legacyFile, to: newFile)
        }
        fileURL = newFile
        var decoded = Self.load(from: fileURL)
        let needsDeveloperSeeds = decoded.dictionarySeedVersion < Payload.currentDictionarySeedVersion
        if needsDeveloperSeeds {
            let existing = Set(decoded.dictionary.map { $0.writtenForm.lowercased() })
            decoded.dictionary.append(contentsOf: Payload.defaultDictionary.filter { !existing.contains($0.writtenForm.lowercased()) })
            decoded.dictionarySeedVersion = Payload.currentDictionarySeedVersion
        }
        dictionary = decoded.dictionary
        snippets = decoded.snippets
        transcripts = decoded.transcripts
        metrics = decoded.metrics
        retention = decoded.retention
        developerMode = decoded.developerMode
        contextEnabled = decoded.contextEnabled
        dictationMode = decoded.dictationMode
        promptLength = decoded.promptLength
        dictionarySeedVersion = decoded.dictionarySeedVersion
        isLoading = false
        prune()
        if needsDeveloperSeeds { save() }
    }

    public func addDictionary(spoken: String, written: String) {
        let spoken = spoken.trimmingCharacters(in: .whitespacesAndNewlines)
        let written = written.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !spoken.isEmpty, !written.isEmpty else { return }
        dictionary.append(DictionaryEntry(spokenForm: spoken, writtenForm: written))
    }

    public func deleteDictionary(ids: Set<UUID>) {
        dictionary.removeAll { ids.contains($0.id) }
    }

    public func addSnippet(name: String, trigger: String, expansion: String) {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trigger = trigger.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !trigger.isEmpty, !expansion.isEmpty else { return }
        snippets.append(Snippet(name: name, trigger: trigger, expansion: expansion))
    }

    public func deleteSnippets(ids: Set<UUID>) {
        snippets.removeAll { ids.contains($0.id) }
    }

    public func record(text: String, duration: TimeInterval, changes: [RefinementChange], mode: DictationMode) {
        let record = TranscriptRecord(text: text, duration: duration)
        metrics.totalWords += record.wordCount
        metrics.dictations += 1
        metrics.captureSeconds += duration
        metrics.fixes += changes.count
        metrics.developerFixes += changes.filter { $0.kind == .developerToken || $0.kind == .correction }.count
        if mode == .prompt { metrics.prompts += 1 }
        if retention != .never {
            transcripts.insert(record, at: 0)
        }
    }

    public func clearHistory() {
        transcripts.removeAll()
    }

    public func resetMetrics() {
        metrics = UsageMetrics()
    }

    private func prune() {
        if retention == .never {
            transcripts.removeAll()
        } else if let cutoff = retention.cutoff {
            transcripts.removeAll { $0.createdAt < cutoff }
        }
    }

    private func save() {
        guard !isLoading else { return }
        let payload = Payload(
            dictionary: dictionary,
            snippets: snippets,
            transcripts: retention == .never ? [] : transcripts,
            metrics: metrics,
            retention: retention,
            developerMode: developerMode,
            contextEnabled: contextEnabled,
            dictationMode: dictationMode,
            promptLength: promptLength,
            dictionarySeedVersion: dictionarySeedVersion
        )
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder.pitchKiwi.encode(payload)
            try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
        } catch {
            // Intentionally no content-bearing log. The UI keeps the in-memory state usable.
        }
    }

    private static func load(from url: URL) -> Payload {
        guard let data = try? Data(contentsOf: url),
              let payload = try? JSONDecoder.pitchKiwi.decode(Payload.self, from: data) else {
            return Payload()
        }
        return payload
    }
}

private struct Payload: Codable {
    static let currentDictionarySeedVersion = 1
    static let defaultDictionary: [DictionaryEntry] = [
        DictionaryEntry(spokenForm: "claude code", writtenForm: "Claude Code"),
        DictionaryEntry(spokenForm: "cursor", writtenForm: "Cursor"),
        DictionaryEntry(spokenForm: "codex", writtenForm: "Codex"),
        DictionaryEntry(spokenForm: "wind surf", writtenForm: "Windsurf"),
        DictionaryEntry(spokenForm: "vercel", writtenForm: "Vercel"),
        DictionaryEntry(spokenForm: "super base", writtenForm: "Supabase"),
        DictionaryEntry(spokenForm: "post gress sequel", writtenForm: "PostgreSQL"),
        DictionaryEntry(spokenForm: "next j s", writtenForm: "Next.js"),
        DictionaryEntry(spokenForm: "tailwind", writtenForm: "Tailwind"),
        DictionaryEntry(spokenForm: "shad c n", writtenForm: "shadcn"),
        DictionaryEntry(spokenForm: "use effect", writtenForm: "useEffect"),
        DictionaryEntry(spokenForm: "local host", writtenForm: "localhost"),
    ]
    var dictionary: [DictionaryEntry] = Self.defaultDictionary
    var snippets: [Snippet] = []
    var transcripts: [TranscriptRecord] = []
    var metrics = UsageMetrics()
    var retention: HistoryRetention = .never
    var developerMode = true
    var contextEnabled = false
    var dictationMode: DictationMode = .dictate
    var promptLength: PromptLength = .medium
    var dictionarySeedVersion = Self.currentDictionarySeedVersion

    private enum CodingKeys: String, CodingKey {
        case dictionary, snippets, transcripts, metrics, retention, developerMode, contextEnabled, dictationMode, promptLength, dictionarySeedVersion
    }

    init() {}

    init(
        dictionary: [DictionaryEntry],
        snippets: [Snippet],
        transcripts: [TranscriptRecord],
        metrics: UsageMetrics,
        retention: HistoryRetention,
        developerMode: Bool,
        contextEnabled: Bool,
        dictationMode: DictationMode,
        promptLength: PromptLength,
        dictionarySeedVersion: Int
    ) {
        self.dictionary = dictionary
        self.snippets = snippets
        self.transcripts = transcripts
        self.metrics = metrics
        self.retention = retention
        self.developerMode = developerMode
        self.contextEnabled = contextEnabled
        self.dictationMode = dictationMode
        self.promptLength = promptLength
        self.dictionarySeedVersion = dictionarySeedVersion
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        dictionary = try values.decodeIfPresent([DictionaryEntry].self, forKey: .dictionary) ?? Self.defaultDictionary
        snippets = try values.decodeIfPresent([Snippet].self, forKey: .snippets) ?? []
        transcripts = try values.decodeIfPresent([TranscriptRecord].self, forKey: .transcripts) ?? []
        metrics = try values.decodeIfPresent(UsageMetrics.self, forKey: .metrics) ?? UsageMetrics()
        retention = try values.decodeIfPresent(HistoryRetention.self, forKey: .retention) ?? .never
        developerMode = try values.decodeIfPresent(Bool.self, forKey: .developerMode) ?? true
        contextEnabled = try values.decodeIfPresent(Bool.self, forKey: .contextEnabled) ?? false
        dictationMode = try values.decodeIfPresent(DictationMode.self, forKey: .dictationMode) ?? .dictate
        promptLength = try values.decodeIfPresent(PromptLength.self, forKey: .promptLength) ?? .medium
        dictionarySeedVersion = try values.decodeIfPresent(Int.self, forKey: .dictionarySeedVersion) ?? 0
    }
}

private extension JSONEncoder {
    static var pitchKiwi: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

private extension JSONDecoder {
    static var pitchKiwi: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
