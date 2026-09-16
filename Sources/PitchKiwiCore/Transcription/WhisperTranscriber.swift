import Foundation
import whisper

public actor WhisperTranscriber: SpeechTranscribing {
    private var contextBox: WhisperContextBox?
    private var loadedModelPath: String?

    public init() {}

    public func transcribe(_ audio: CapturedAudio, modelURL: URL, hints: [String]) async throws -> RawTranscript {
        guard audio.sampleRate == 16_000, !audio.samples.isEmpty else {
            throw PitchKiwiError.noSpeech
        }

        guard AudioSpeechGate.hasLikelySpeech(
            samples: audio.samples,
            duration: audio.duration
        ) else { throw PitchKiwiError.noSpeech }

        try loadModelIfNeeded(modelURL)
        guard let context = contextBox?.pointer else { throw PitchKiwiError.modelMissing }

        // Beam search is slower than a single greedy pass, but materially more
        // reliable for names, developer vocabulary, and mid-sentence
        // corrections. Keep context across Whisper's internal windows so long
        // dictations stay coherent instead of decoding each segment in
        // isolation.
        var params = whisper_full_default_params(WHISPER_SAMPLING_BEAM_SEARCH)
        params.n_threads = Int32(min(8, max(2, ProcessInfo.processInfo.activeProcessorCount - 2)))
        params.translate = false
        params.no_context = false
        params.no_timestamps = true
        params.print_special = false
        params.print_progress = false
        params.print_realtime = false
        params.print_timestamps = false
        params.single_segment = false
        params.suppress_blank = true
        params.suppress_nst = true
        params.temperature = 0
        params.beam_search.beam_size = 5
        params.beam_search.patience = 1

        let prompt = hints.prefix(40).joined(separator: ", ")
        let result: Int32 = "en".withCString { languagePointer in
            prompt.withCString { promptPointer in
                params.language = languagePointer
                params.initial_prompt = prompt.isEmpty ? nil : promptPointer
                params.carry_initial_prompt = !prompt.isEmpty
                return audio.samples.withUnsafeBufferPointer { buffer in
                    guard let base = buffer.baseAddress else { return -1 }
                    return Int32(whisper_full(context, params, base, Int32(buffer.count)))
                }
            }
        }
        guard result == 0 else { throw PitchKiwiError.transcriptionFailed }

        let count = whisper_full_n_segments(context)
        var text = ""
        var highestNoSpeechProbability: Float = 0
        var tokenProbabilityTotal: Float = 0
        var tokenProbabilityCount = 0
        for index in 0..<count {
            highestNoSpeechProbability = max(
                highestNoSpeechProbability,
                whisper_full_get_segment_no_speech_prob(context, index)
            )
            if let pointer = whisper_full_get_segment_text(context, index) {
                text += String(cString: pointer)
            }
            let tokenCount = whisper_full_n_tokens(context, index)
            for tokenIndex in 0..<tokenCount {
                tokenProbabilityTotal += whisper_full_get_token_p(context, index, tokenIndex)
                tokenProbabilityCount += 1
            }
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let averageTokenProbability = tokenProbabilityCount > 0
            ? tokenProbabilityTotal / Float(tokenProbabilityCount)
            : 0
        guard TranscriptSpeechGate.accepts(
            text: trimmed,
            highestNoSpeechProbability: highestNoSpeechProbability,
            averageTokenProbability: averageTokenProbability
        ) else {
            throw PitchKiwiError.noSpeech
        }
        return RawTranscript(text: trimmed)
    }

    private func loadModelIfNeeded(_ modelURL: URL) throws {
        let path = modelURL.path
        if loadedModelPath == path, contextBox != nil { return }
        contextBox = nil

        guard FileManager.default.fileExists(atPath: path) else {
            throw PitchKiwiError.modelMissing
        }

        var parameters = whisper_context_default_params()
        parameters.use_gpu = true
        parameters.flash_attn = true
        let loaded = path.withCString { whisper_init_from_file_with_params($0, parameters) }
        guard let loaded else { throw PitchKiwiError.modelInvalid }
        contextBox = WhisperContextBox(pointer: loaded)
        loadedModelPath = path
    }
}

enum AudioSpeechGate {
    static func hasLikelySpeech(samples: [Float], duration: TimeInterval) -> Bool {
        guard duration >= 0.25, !samples.isEmpty else { return false }
        let rootMeanSquare = sqrt(samples.reduce(0) { $0 + ($1 * $1) } / Float(samples.count))
        let voicedSampleRatio = Float(samples.lazy.filter { abs($0) > 0.012 }.count) / Float(samples.count)
        return rootMeanSquare > 0.0025 && voicedSampleRatio > 0.002
    }
}

enum TranscriptSpeechGate {
    private static let knownSilenceMarkers: Set<String> = [
        "blank audio", "silence", "no speech", "inaudible", "music", "background noise",
    ]

    static func accepts(
        text: String,
        highestNoSpeechProbability: Float,
        averageTokenProbability: Float
    ) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        guard !trimmed.isEmpty, !knownSilenceMarkers.contains(normalized) else { return false }
        return !(highestNoSpeechProbability > 0.60 && averageTokenProbability < 0.45)
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
