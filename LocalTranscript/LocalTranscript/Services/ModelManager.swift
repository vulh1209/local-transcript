import Foundation
import WhisperKit

/// Describes an available Whisper model variant
struct WhisperModel: Identifiable {
    let id: String      // Model identifier for WhisperKit (e.g., "small")
    let name: String    // Display name (e.g., "Small")
    let size: String    // Approximate download size (e.g., "~250MB")
    let description: String  // Brief description
}

@Observable
class ModelManager {
    /// Available model sizes from smallest/fastest to largest/most accurate
    static let availableModels: [WhisperModel] = [
        WhisperModel(id: "tiny", name: "Tiny", size: "~40MB", description: "Fastest, lower accuracy"),
        WhisperModel(id: "base", name: "Base", size: "~75MB", description: "Fast, decent accuracy"),
        WhisperModel(id: "small", name: "Small", size: "~250MB", description: "Balanced speed/accuracy"),
        WhisperModel(id: "medium", name: "Medium", size: "~750MB", description: "Better accuracy, slower"),
        WhisperModel(id: "large-v3", name: "Large", size: "~1.5GB", description: "Best accuracy, slowest"),
    ]

    private(set) var whisperKit: WhisperKit?
    private(set) var isLoading = false
    private(set) var loadError: Error?
    private(set) var loadProgress: String = ""

    /// Download progress callback for UI updates (0.0 to 1.0)
    var onDownloadProgress: ((Double) -> Void)?

    // Use UserDefaults directly to avoid @AppStorage conflict with @Observable macro
    @ObservationIgnored
    var selectedModel: String {
        get { UserDefaults.standard.string(forKey: "selectedModel") ?? "small" }
        set { UserDefaults.standard.set(newValue, forKey: "selectedModel") }
    }

    private(set) var downloadProgress: Double = 0
    private(set) var isDownloading = false

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

    /// Get the currently selected model info
    var currentModelInfo: WhisperModel? {
        Self.availableModels.first { $0.id == selectedModel }
    }

    /// Load WhisperKit model. Downloads automatically if not present.
    /// Uses the selected model (defaults to "small" - multilingual, auto-detects Vietnamese/English).
    func loadModel() async throws {
        guard whisperKit == nil, !isLoading else { return }

        isLoading = true
        isDownloading = true
        downloadProgress = 0
        loadError = nil
        loadProgress = "Initializing WhisperKit..."

        defer {
            isLoading = false
            isDownloading = false
            loadProgress = ""
        }

        do {
            loadProgress = "Downloading model..."

            // Download model with progress tracking
            let modelFolder = try await WhisperKit.download(
                variant: selectedModel,
                from: "argmaxinc/whisperkit-coreml",
                progressCallback: { [weak self] progress in
                    Task { @MainActor [weak self] in
                        self?.downloadProgress = progress.fractionCompleted
                        self?.onDownloadProgress?(progress.fractionCompleted)
                    }
                }
            )

            loadProgress = "Loading model..."
            downloadProgress = 1.0
            onDownloadProgress?(1.0)

            // Initialize WhisperKit with the downloaded model folder
            whisperKit = try await WhisperKit(
                modelFolder: modelFolder.path,
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

    /// Switch to a different model
    /// - Parameter model: Model ID to switch to (e.g., "tiny", "small", "large-v3")
    func switchModel(to model: String) async throws {
        // Skip if same model is already loaded
        guard whisperKit == nil || model != selectedModel else { return }

        selectedModel = model
        unloadModel()
        try await loadModel()
    }

    /// Unload model to free memory
    func unloadModel() {
        whisperKit = nil
    }
}
