import Foundation

/// Thread-safe circular buffer for Float audio samples
///
/// Used for continuous audio recording where we need bounded storage
/// with the ability to extract recent samples for transcription while
/// keeping older samples for overlap/context.
///
/// Thread safety: Uses NSLock for synchronization between audio thread (writes)
/// and main thread (reads/extracts).
final class CircularAudioBuffer: @unchecked Sendable {
    /// Default capacity: 60 seconds at 16kHz = 960,000 samples
    static let defaultCapacity = 60 * 16000

    private var buffer: [Float]
    private var writeIndex: Int = 0
    private var storedCount: Int = 0
    private let capacity: Int
    private let lock = NSLock()

    /// Create a circular buffer with specified capacity
    /// - Parameter capacity: Maximum number of Float samples to store (default: 60s at 16kHz)
    init(capacity: Int = CircularAudioBuffer.defaultCapacity) {
        self.capacity = capacity
        self.buffer = [Float](repeating: 0, count: capacity)
    }

    /// Number of samples currently stored in the buffer
    var availableCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return storedCount
    }

    /// Whether the buffer is empty
    var isEmpty: Bool {
        availableCount == 0
    }

    /// Whether the buffer is full
    var isFull: Bool {
        availableCount == capacity
    }

    /// Write samples to the buffer
    /// If buffer is full, oldest samples are overwritten.
    /// - Parameter samples: Audio samples to write
    func write(_ samples: [Float]) {
        guard !samples.isEmpty else { return }

        lock.lock()
        defer { lock.unlock() }

        for sample in samples {
            buffer[writeIndex] = sample
            writeIndex = (writeIndex + 1) % capacity
        }

        // Update stored count, capped at capacity
        storedCount = min(storedCount + samples.count, capacity)
    }

    /// Read most recent N samples without removing them
    /// - Parameter count: Number of samples to read
    /// - Returns: Array of samples (may be fewer if buffer has less)
    func read(count: Int) -> [Float] {
        lock.lock()
        defer { lock.unlock() }

        let readCount = min(count, storedCount)
        guard readCount > 0 else { return [] }

        // Calculate start index for reading most recent samples
        let startIndex = (writeIndex - readCount + capacity) % capacity

        var result = [Float](repeating: 0, count: readCount)
        for i in 0..<readCount {
            result[i] = buffer[(startIndex + i) % capacity]
        }
        return result
    }

    /// Extract all samples from the buffer and clear it
    /// - Returns: All stored samples in order (oldest to newest)
    func extract() -> [Float] {
        lock.lock()
        defer { lock.unlock() }

        guard storedCount > 0 else { return [] }

        // Calculate start index (oldest sample)
        let startIndex = (writeIndex - storedCount + capacity) % capacity

        var result = [Float](repeating: 0, count: storedCount)
        for i in 0..<storedCount {
            result[i] = buffer[(startIndex + i) % capacity]
        }

        // Clear buffer
        storedCount = 0

        return result
    }

    /// Extract samples but keep the last N samples in the buffer
    /// Useful for overlap between transcription segments.
    /// - Parameter keepLast: Number of samples to keep in buffer after extraction
    /// - Returns: All samples before the kept portion
    func extractAndKeep(keepLast: Int) -> [Float] {
        lock.lock()
        defer { lock.unlock() }

        let keepCount = min(keepLast, storedCount)
        let extractCount = storedCount - keepCount

        guard extractCount > 0 else { return [] }

        // Calculate start index (oldest sample to extract)
        let startIndex = (writeIndex - storedCount + capacity) % capacity

        var result = [Float](repeating: 0, count: extractCount)
        for i in 0..<extractCount {
            result[i] = buffer[(startIndex + i) % capacity]
        }

        // Update stored count to only keep the last N samples
        storedCount = keepCount

        return result
    }

    /// Clear all samples from the buffer
    func clear() {
        lock.lock()
        defer { lock.unlock() }
        storedCount = 0
    }

    /// Get current duration in seconds (at 16kHz sample rate)
    var durationSeconds: Double {
        Double(availableCount) / 16000.0
    }
}
