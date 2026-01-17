import AVFoundation

@Observable
class AudioRecorder {
    private var audioEngine: AVAudioEngine?
    private var audioConverter: AVAudioConverter?
    private var accumulatedSamples: [Float] = []

    private(set) var isRecording = false

    private let targetFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: 16000,
        channels: 1,
        interleaved: false
    )!

    enum AudioError: LocalizedError {
        case converterCreationFailed

        var errorDescription: String? {
            switch self {
            case .converterCreationFailed:
                return "Failed to create audio format converter"
            }
        }
    }

    /// Start recording from microphone, converting audio to 16kHz mono Float32.
    /// Requires microphone permission to be granted.
    func startRecording() throws {
        guard !isRecording else { return }

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode

        // Query native format at runtime - do NOT hardcode sample rate
        // AirPods may be 16kHz, built-in mic 44.1kHz, USB mics 48kHz
        let inputFormat = inputNode.inputFormat(forBus: 0)

        // Create converter from native input format to 16kHz mono Float32 (Whisper requirement)
        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            throw AudioError.converterCreationFailed
        }

        audioConverter = converter
        accumulatedSamples = []

        // Install tap on input node - callback runs on audio thread
        // Keep processing minimal: only convert and append
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            self?.processBuffer(buffer)
        }

        engine.prepare()
        try engine.start()

        audioEngine = engine
        isRecording = true
    }

    /// Stop recording and return accumulated audio samples.
    /// Returns [Float] samples at 16kHz mono, ready for Whisper transcription.
    func stopRecording() -> [Float] {
        guard isRecording, let engine = audioEngine else { return [] }

        engine.inputNode.removeTap(onBus: 0)
        engine.stop()

        isRecording = false
        audioEngine = nil
        audioConverter = nil

        // Return samples and clear accumulator
        let samples = accumulatedSamples
        accumulatedSamples = []
        return samples
    }

    /// Convert incoming buffer to 16kHz mono and append to accumulated samples.
    /// This runs on the audio thread - keep it fast.
    private func processBuffer(_ inputBuffer: AVAudioPCMBuffer) {
        guard let converter = audioConverter else { return }

        // Calculate output frame count based on input duration and target sample rate
        let duration = Double(inputBuffer.frameLength) / inputBuffer.format.sampleRate
        let outputFrameCapacity = AVAudioFrameCount(16000.0 * duration)

        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: outputFrameCapacity
        ) else { return }

        var error: NSError?
        var inputBufferConsumed = false

        // AVAudioConverter.convert uses a callback pattern for input data
        converter.convert(to: outputBuffer, error: &error) { _, outStatus in
            if inputBufferConsumed {
                outStatus.pointee = .noDataNow
                return nil
            }
            inputBufferConsumed = true
            outStatus.pointee = .haveData
            return inputBuffer
        }

        // Extract Float samples from converted buffer
        if let channelData = outputBuffer.floatChannelData?[0] {
            let samples = Array(UnsafeBufferPointer(
                start: channelData,
                count: Int(outputBuffer.frameLength)
            ))
            accumulatedSamples.append(contentsOf: samples)
        }
    }
}
