import AVFoundation

/// Captures microphone audio and resamples it to 16 kHz mono Float32 — the
/// format both WhisperKit and our Apple-Speech wrapper consume.
///
/// The AVAudioEngine tap runs on a real-time audio thread, so `samples` is
/// guarded by a lock; `stop()` reads it back on the main thread afterwards.
final class AudioRecorder {
    /// Target sample rate handed to the transcription engines.
    let sampleRate: Double = 16_000

    /// Called on the main thread with a normalized 0…1 loudness level for each
    /// captured buffer — drives the live waveform in the recording overlay.
    var onLevel: ((Float) -> Void)?

    private let engine = AVAudioEngine()
    private let targetFormat: AVAudioFormat
    private var converter: AVAudioConverter?
    private let lock = NSLock()
    private var samples: [Float] = []
    private var isRecording = false

    init() {
        targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16_000,
            channels: 1,
            interleaved: false
        )!
    }

    func start() throws {
        guard !isRecording else { return }
        lock.lock(); samples.removeAll(keepingCapacity: true); lock.unlock()

        let input = engine.inputNode
        let inputFormat = input.inputFormat(forBus: 0)
        converter = AVAudioConverter(from: inputFormat, to: targetFormat)

        input.installTap(onBus: 0, bufferSize: 2048, format: inputFormat) { [weak self] buffer, _ in
            self?.append(buffer)
        }
        engine.prepare()
        try engine.start()
        isRecording = true
    }

    /// Stops capture and returns the full 16 kHz mono clip.
    @discardableResult
    func stop() -> [Float] {
        guard isRecording else {
            lock.lock(); defer { lock.unlock() }; return samples
        }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRecording = false
        lock.lock(); let out = samples; lock.unlock()
        return out
    }

    private func append(_ buffer: AVAudioPCMBuffer) {
        guard let converter else { return }
        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1024
        guard let out = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else { return }

        var supplied = false
        var error: NSError?
        converter.convert(to: out, error: &error) { _, status in
            if supplied {
                status.pointee = .noDataNow
                return nil
            }
            supplied = true
            status.pointee = .haveData
            return buffer
        }
        if error != nil { return }

        guard let channel = out.floatChannelData, out.frameLength > 0 else { return }
        let count = Int(out.frameLength)
        lock.lock()
        samples.append(contentsOf: UnsafeBufferPointer(start: channel[0], count: count))
        lock.unlock()

        emitLevels(from: channel[0], count: count)
    }

    /// Splits the buffer into a few sub-windows and reports a normalized (dB-
    /// mapped) level for each, so the waveform stays lively regardless of the
    /// hardware buffer size.
    private func emitLevels(from data: UnsafePointer<Float>, count: Int) {
        guard let onLevel, count > 0 else { return }
        let windows = 4
        let windowSize = max(1, count / windows)
        var levels: [Float] = []
        var start = 0
        while start < count {
            let end = min(start + windowSize, count)
            var sumSquares: Float = 0
            for i in start..<end { sumSquares += data[i] * data[i] }
            let rms = sqrt(sumSquares / Float(end - start))
            let db = 20 * log10(max(rms, 1e-7))          // ~ -140…0 dB
            let level = max(0, min(1, (db + 50) / 50))    // -50 dB → 0, 0 dB → 1
            levels.append(level)
            start = end
        }
        DispatchQueue.main.async {
            for level in levels { onLevel(level) }
        }
    }
}
