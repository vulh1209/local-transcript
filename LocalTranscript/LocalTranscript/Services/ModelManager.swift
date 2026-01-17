import Foundation
import SwiftWhisper

@Observable
class ModelManager {
    private(set) var whisper: Whisper?
    private(set) var isLoading = false
    private(set) var loadError: Error?
    private(set) var loadProgress: String = ""

    enum ModelError: LocalizedError {
        case modelNotFound
        case loadFailed(Error)

        var errorDescription: String? {
            switch self {
            case .modelNotFound:
                return "PhoWhisper model file not found. Please download the model."
            case .loadFailed(let error):
                return "Failed to load model: \(error.localizedDescription)"
            }
        }
    }

    var isModelLoaded: Bool {
        whisper != nil
    }

    var modelStoragePath: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let appFolder = appSupport.appendingPathComponent("LocalTranscript", isDirectory: true)

        // Create directory if needed
        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)

        return appFolder
    }

    var modelFilePath: URL {
        modelStoragePath.appendingPathComponent("ggml-phowhisper-medium.bin")
    }

    var isModelFilePresent: Bool {
        FileManager.default.fileExists(atPath: modelFilePath.path)
    }

    /// Load model asynchronously. Call this on first recording trigger, not app launch.
    func loadModel() async throws {
        guard whisper == nil, !isLoading else { return }

        isLoading = true
        loadError = nil
        loadProgress = "Loading model..."

        defer {
            isLoading = false
            loadProgress = ""
        }

        // Check for model in Application Support first
        var modelURL = modelFilePath
        if !FileManager.default.fileExists(atPath: modelURL.path) {
            // Fallback to bundled model (if included in app bundle)
            if let bundledURL = Bundle.main.url(forResource: "ggml-phowhisper-medium", withExtension: "bin") {
                modelURL = bundledURL
            } else {
                throw ModelError.modelNotFound
            }
        }

        loadProgress = "Initializing PhoWhisper..."

        do {
            // SwiftWhisper loads synchronously but we're in async context
            // This prevents UI blocking
            whisper = try await Task.detached(priority: .userInitiated) {
                Whisper(fromFileURL: modelURL)
            }.value

            if whisper == nil {
                throw ModelError.modelNotFound
            }
        } catch {
            loadError = error
            throw ModelError.loadFailed(error)
        }
    }

    /// Unload model to free memory (call after period of inactivity)
    func unloadModel() {
        whisper = nil
    }
}
