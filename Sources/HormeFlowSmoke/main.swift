import Foundation
import HormeFlowCore

@main
struct HormeFlowSmoke {
    static func main() async {
        let arguments = CommandLine.arguments
        guard arguments.count == 3 else {
            FileHandle.standardError.write(Data("Usage: horme-flow-smoke <model.bin> <audio-file>\n".utf8))
            Foundation.exit(2)
        }

        do {
            let model = URL(fileURLWithPath: arguments[1])
            let audio = try AudioFileLoader.load(url: URL(fileURLWithPath: arguments[2]))
            let transcript = try await WhisperTranscriber().transcribe(audio, modelURL: model, hints: ["Horme Flow", "userId", "package.json"])
            let refined = DeterministicRefiner().refine(text: transcript.text, dictionary: [], snippets: [], developerMode: true)
            print(refined.text)
        } catch {
            FileHandle.standardError.write(Data("Smoke test failed: \(error.localizedDescription)\n".utf8))
            Foundation.exit(1)
        }
    }
}
