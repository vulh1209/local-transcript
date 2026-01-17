import Foundation
import WhisperKit

@Observable
class ModelManager {
    private(set) var whisperKit: WhisperKit?
    private(set) var isLoading = false
    private(set) var loadError: Error?
    private(set) var loadProgress: String = ""

    enum ModelError: LocalizedError {
        case modelNotFound
        case loadFailed(Error)

        var errorDescription: String? {
            switch self {
            case .modelNotFound:
                return "Whisper model not found. Will download automatically."
            case .loadFailed(let error):
                return "Failed to load model: \(error.localizedDescription)"
            }
        }
    }

    var isModelLoaded: Bool {
        whisperKit != nil
    }

    /// Load WhisperKit model. Downloads automatically if not present.
    /// Uses "small" model - multilingual, auto-detects Vietnamese/English.
    func loadModel() async throws {
        guard whisperKit == nil, !isLoading else { return }

        isLoading = true
        loadError = nil
        loadProgress = "Initializing WhisperKit..."

        defer {
            isLoading = false
            loadProgress = ""
        }

        do {
            loadProgress = "Loading model (may download on first run)..."

            // WhisperKit downloads models automatically to ~/Library/Caches/
            // Use "small" model for good quality with reasonable speed
            whisperKit = try await WhisperKit(
                model: "small",
                downloadBase: nil,  // Use default cache location
                modelRepo: nil,     // Use default HuggingFace repo
                modelFolder: nil,   // Auto-managed
                tokenizerFolder: nil,
                computeOptions: nil,
                audioProcessor: nil,
                featureExtractor: nil,
                audioEncoder: nil,
                textDecoder: nil,
                logitsFilters: nil,
                segmentSeeker: nil,
                verbose: false,
                logLevel: .error,
                prewarm: true,
                load: true,
                useBackgroundDownloadSession: false
            )

            if whisperKit == nil {
                throw ModelError.modelNotFound
            }
        } catch {
            loadError = error
            throw ModelError.loadFailed(error)
        }
    }

    /// Unload model to free memory
    func unloadModel() {
        whisperKit = nil
    }
}
