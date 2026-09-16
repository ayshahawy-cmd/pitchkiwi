import AVFoundation
import Foundation

public final class AVAudioCaptureService: AudioCapturing, @unchecked Sendable {
    private let engine = AVAudioEngine()
    private let lock = NSLock()
    private var samples: [Float] = []
    private var nativeSampleRate: Double = 48_000
    private var startedAt: Date?
    private var running = false
    private var smoothedLevel: Float = 0
    public let levels: AsyncStream<Float>
    private let levelContinuation: AsyncStream<Float>.Continuation

    public init() {
        let pair = AsyncStream<Float>.makeStream(bufferingPolicy: .bufferingNewest(1))
        levels = pair.stream
        levelContinuation = pair.continuation
    }

    public func start() async throws {
        let allowed = await requestMicrophoneAccess()
        guard allowed else { throw PitchKiwiError.microphonePermissionDenied }

        lock.withLock {
            samples.removeAll(keepingCapacity: true)
            startedAt = Date()
            smoothedLevel = 0
        }

        let input = engine.inputNode
        let format = input.inputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw PitchKiwiError.microphoneUnavailable
        }
        nativeSampleRate = format.sampleRate
        let maximumFrames = Int(format.sampleRate * 300)

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1_024, format: format) { [weak self] buffer, _ in
            guard let self, let channel = buffer.floatChannelData?.pointee else { return }
            let count = Int(buffer.frameLength)
            let values = UnsafeBufferPointer(start: channel, count: count)
            let rawLevel = AudioLevelMeter.normalized(values)
            let visibleLevel = self.lock.withLock { () -> Float in
                let response: Float = rawLevel > self.smoothedLevel ? 0.68 : 0.24
                self.smoothedLevel += (rawLevel - self.smoothedLevel) * response
                if self.samples.count < maximumFrames {
                    let accepted = min(count, maximumFrames - self.samples.count)
                    self.samples.append(contentsOf: values.prefix(accepted))
                }
                return self.smoothedLevel
            }
            self.levelContinuation.yield(visibleLevel)
        }

        engine.prepare()
        do {
            try engine.start()
            running = true
        } catch {
            input.removeTap(onBus: 0)
            clear()
            throw PitchKiwiError.microphoneUnavailable
        }
    }

    public func stop() async throws -> CapturedAudio {
        guard running else { throw PitchKiwiError.microphoneUnavailable }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        running = false
        levelContinuation.yield(0)

        let (captured, start) = lock.withLock {
            let result = (samples, startedAt)
            samples.removeAll(keepingCapacity: false)
            startedAt = nil
            return result
        }

        let converted = Self.resample(captured, from: nativeSampleRate, to: 16_000)
        let duration = start.map { Date().timeIntervalSince($0) } ?? (Double(captured.count) / nativeSampleRate)
        return CapturedAudio(samples: converted, sampleRate: 16_000, duration: duration)
    }

    public func cancel() async {
        if running {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
            running = false
        }
        levelContinuation.yield(0)
        clear()
    }

    private func clear() {
        lock.withLock {
            samples.removeAll(keepingCapacity: false)
            startedAt = nil
            smoothedLevel = 0
        }
    }

    private func requestMicrophoneAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .audio)
        default:
            return false
        }
    }

    public static func resample(_ input: [Float], from sourceRate: Double, to targetRate: Double) -> [Float] {
        guard !input.isEmpty, sourceRate > 0, targetRate > 0 else { return [] }
        guard abs(sourceRate - targetRate) > 0.1 else { return input }

        let ratio = sourceRate / targetRate
        let outputCount = max(1, Int(Double(input.count) / ratio))
        var output = [Float](repeating: 0, count: outputCount)
        for index in 0..<outputCount {
            let position = Double(index) * ratio
            let lower = min(Int(position), input.count - 1)
            let upper = min(lower + 1, input.count - 1)
            let fraction = Float(position - Double(lower))
            output[index] = input[lower] + (input[upper] - input[lower]) * fraction
        }
        return output
    }
}

enum AudioLevelMeter {
    static func normalized<S: Sequence>(_ samples: S) -> Float where S.Element == Float {
        var sumOfSquares: Float = 0
        var peak: Float = 0
        var count: Float = 0
        for sample in samples {
            sumOfSquares += sample * sample
            peak = max(peak, abs(sample))
            count += 1
        }
        guard count > 0 else { return 0 }

        let rootMeanSquare = sqrt(sumOfSquares / count)
        let rmsDecibels = 20 * log10(max(rootMeanSquare, 0.000_01))
        let peakDecibels = 20 * log10(max(peak, 0.000_01))
        let rmsLevel = min(1, max(0, (rmsDecibels + 62) / 42))
        let peakLevel = min(1, max(0, (peakDecibels + 58) / 46))
        let combined = max(rmsLevel, peakLevel * 0.85)
        guard combined >= 0.03 else { return 0 }
        return min(1, pow(combined, 0.78))
    }
}
