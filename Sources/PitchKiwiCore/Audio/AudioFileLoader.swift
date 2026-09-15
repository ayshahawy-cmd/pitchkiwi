import AVFoundation
import Foundation

public enum AudioFileLoader {
    public static func load(url: URL) throws -> CapturedAudio {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        guard format.channelCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(file.length)) else {
            throw PitchKiwiError.microphoneUnavailable
        }
        try file.read(into: buffer)
        guard let channel = buffer.floatChannelData?.pointee else {
            throw PitchKiwiError.microphoneUnavailable
        }
        let samples = Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
        let converted = AVAudioCaptureService.resample(samples, from: format.sampleRate, to: 16_000)
        return CapturedAudio(
            samples: converted,
            sampleRate: 16_000,
            duration: Double(samples.count) / format.sampleRate
        )
    }
}

