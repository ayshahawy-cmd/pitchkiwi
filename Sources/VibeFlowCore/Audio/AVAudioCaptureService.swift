import AVFoundation
import Foundation

public final class AVAudioCaptureService: AudioCapturing, @unchecked Sendable {
    private let engine = AVAudioEngine()
    private let lock = NSLock()
    private var samples: [Float] = []
    private var nativeSampleRate: Double = 48_000
    private var startedAt: Date?
    private var running = false
    public let levels: AsyncStream<Float>
    private let levelContinuation: AsyncStream<Float>.Continuation

    public init() {
        let pair = AsyncStream<Float>.makeStream(bufferingPolicy: .bufferingNewest(1))
        levels = pair.stream
        levelContinuation = pair.continuation
    }

    public func start() async throws {
        let allowed = await requestMicrophoneAccess()
        guard allowed else { throw VibeFlowError.microphonePermissionDenied }

        lock.withLock {
            samples.removeAll(keepingCapacity: true)
            startedAt = Date()
        }

        let input = engine.inputNode
        let format = input.inputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw VibeFlowError.microphoneUnavailable
        }
        nativeSampleRate = format.sampleRate
        let maximumFrames = Int(format.sampleRate * 300)

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1_024, format: format) { [weak self] buffer, _ in
            guard let self, let channel = buffer.floatChannelData?.pointee else { return }
            let count = Int(buffer.frameLength)
            let values = UnsafeBufferPointer(start: channel, count: count)
            let meanSquare = values.reduce(Float.zero) { $0 + ($1 * $1) } / Float(max(count, 1))
            let decibels = 20 * log10(max(sqrt(meanSquare), 0.000_1))
            let normalizedLevel = min(1, max(0, (decibels + 55) / 45))
            self.levelContinuation.yield(normalizedLevel)
            self.lock.withLock {
                if self.samples.count < maximumFrames {
                    let accepted = min(count, maximumFrames - self.samples.count)
                    self.samples.append(contentsOf: values.prefix(accepted))
                }
            }
        }

        engine.prepare()
        do {
            try engine.start()
            running = true
        } catch {
            input.removeTap(onBus: 0)
            clear()
            throw VibeFlowError.microphoneUnavailable
        }
    }

    public func stop() async throws -> CapturedAudio {
        guard running else { throw VibeFlowError.microphoneUnavailable }
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
