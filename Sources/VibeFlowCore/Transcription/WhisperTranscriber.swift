import Foundation
import whisper

public actor WhisperTranscriber: SpeechTranscribing {
    private var contextBox: WhisperContextBox?
    private var loadedModelPath: String?

    public init() {}

    public func transcribe(_ audio: CapturedAudio, modelURL: URL, hints: [String]) async throws -> RawTranscript {
        guard audio.sampleRate == 16_000, !audio.samples.isEmpty else {
            throw VibeFlowError.noSpeech
        }

        let energy = sqrt(audio.samples.reduce(0) { $0 + ($1 * $1) } / Float(audio.samples.count))
        guard energy > 0.0015 else { throw VibeFlowError.noSpeech }

        try loadModelIfNeeded(modelURL)
        guard let context = contextBox?.pointer else { throw VibeFlowError.modelMissing }

        var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
        params.n_threads = Int32(min(8, max(2, ProcessInfo.processInfo.activeProcessorCount - 2)))
        params.translate = false
        params.no_context = true
        params.no_timestamps = true
        params.print_special = false
        params.print_progress = false
        params.print_realtime = false
        params.print_timestamps = false
        params.single_segment = false
        params.suppress_blank = true
        params.temperature = 0

        let prompt = hints.prefix(40).joined(separator: ", ")
        let result: Int32 = "en".withCString { languagePointer in
            prompt.withCString { promptPointer in
                params.language = languagePointer
                params.initial_prompt = prompt.isEmpty ? nil : promptPointer
                return audio.samples.withUnsafeBufferPointer { buffer in
                    guard let base = buffer.baseAddress else { return -1 }
                    return Int32(whisper_full(context, params, base, Int32(buffer.count)))
                }
            }
        }
        guard result == 0 else { throw VibeFlowError.transcriptionFailed }

        let count = whisper_full_n_segments(context)
        var text = ""
        for index in 0..<count {
            if let pointer = whisper_full_get_segment_text(context, index) {
                text += String(cString: pointer)
            }
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw VibeFlowError.noSpeech }
        return RawTranscript(text: trimmed)
    }

    private func loadModelIfNeeded(_ modelURL: URL) throws {
        let path = modelURL.path
        if loadedModelPath == path, contextBox != nil { return }
        contextBox = nil

        guard FileManager.default.fileExists(atPath: path) else {
            throw VibeFlowError.modelMissing
        }

        var parameters = whisper_context_default_params()
        parameters.use_gpu = true
        parameters.flash_attn = true
        let loaded = path.withCString { whisper_init_from_file_with_params($0, parameters) }
        guard let loaded else { throw VibeFlowError.modelInvalid }
        contextBox = WhisperContextBox(pointer: loaded)
        loadedModelPath = path
    }
}

private final class WhisperContextBox: @unchecked Sendable {
    let pointer: OpaquePointer

    init(pointer: OpaquePointer) {
        self.pointer = pointer
    }

    deinit {
        whisper_free(pointer)
    }
}
