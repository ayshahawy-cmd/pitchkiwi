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

    private let fileURL: URL
    private var isLoading = true

    public init(directory: URL? = nil) {
        let root = directory ?? ModelManager.appSupportDirectory()
        fileURL = root.appendingPathComponent("vibeflow.json")
        let decoded = Self.load(from: fileURL)
        dictionary = decoded.dictionary
        snippets = decoded.snippets
        transcripts = decoded.transcripts
        metrics = decoded.metrics
        retention = decoded.retention
        developerMode = decoded.developerMode
        contextEnabled = decoded.contextEnabled
        isLoading = false
        prune()
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

    public func record(text: String, duration: TimeInterval, fixes: Int) {
        let record = TranscriptRecord(text: text, duration: duration)
        metrics.totalWords += record.wordCount
        metrics.dictations += 1
        metrics.captureSeconds += duration
        metrics.fixes += fixes
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
            contextEnabled: contextEnabled
        )
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder.vibeFlow.encode(payload)
            try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
        } catch {
            // Intentionally no content-bearing log. The UI keeps the in-memory state usable.
        }
    }

    private static func load(from url: URL) -> Payload {
        guard let data = try? Data(contentsOf: url),
              let payload = try? JSONDecoder.vibeFlow.decode(Payload.self, from: data) else {
            return Payload()
        }
        return payload
    }
}

private struct Payload: Codable {
    var dictionary: [DictionaryEntry] = [
        DictionaryEntry(spokenForm: "super base", writtenForm: "Supabase"),
        DictionaryEntry(spokenForm: "post gress sequel", writtenForm: "PostgreSQL"),
    ]
    var snippets: [Snippet] = []
    var transcripts: [TranscriptRecord] = []
    var metrics = UsageMetrics()
    var retention: HistoryRetention = .never
    var developerMode = true
    var contextEnabled = false
}

private extension JSONEncoder {
    static var vibeFlow: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

private extension JSONDecoder {
    static var vibeFlow: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
