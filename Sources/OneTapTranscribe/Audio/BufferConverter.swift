import AVFoundation

/// Converts a PCM buffer to a target `AVAudioFormat` (sample-rate + layout),
/// reusing one `AVAudioConverter` across calls. Used to feed the exact format
/// `SpeechAnalyzer.bestAvailableAudioFormat` asks for.
final class BufferConverter {
    enum ConvertError: Error {
        case cannotCreateConverter
        case cannotCreateBuffer
        case conversionFailed(NSError?)
    }

    private var converter: AVAudioConverter?

    func convert(_ buffer: AVAudioPCMBuffer, to format: AVAudioFormat) throws -> AVAudioPCMBuffer {
        guard buffer.format != format else { return buffer }

        if converter == nil || converter?.outputFormat != format || converter?.inputFormat != buffer.format {
            converter = AVAudioConverter(from: buffer.format, to: format)
            converter?.primeMethod = .none   // avoid warm-up latency / timestamp drift
        }
        guard let converter else { throw ConvertError.cannotCreateConverter }

        let ratio = format.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up)) + 1024
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else {
            throw ConvertError.cannotCreateBuffer
        }

        var supplied = false
        var nsError: NSError?
        let status = converter.convert(to: output, error: &nsError) { _, statusPtr in
            if supplied {
                statusPtr.pointee = .noDataNow
                return nil
            }
            supplied = true
            statusPtr.pointee = .haveData
            return buffer
        }
        if status == .error { throw ConvertError.conversionFailed(nsError) }
        return output
    }
}
