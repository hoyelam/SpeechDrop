import Foundation
import WhisperKit
import os.log

@MainActor
@Observable
final class TranscriptionService {
    private let logger = Logger(subsystem: "com.kin-yee.SpeechDrop", category: "Transcription")
    enum ModelState {
        case notLoaded
        case loading
        case loaded
        case failed(Error)
    }

    enum TranscriptionError: LocalizedError {
        case modelLoadFailed(Error)
        case transcriptionFailed(Error)
        case invalidAudioFile
        case modelNotAvailable

        var errorDescription: String? {
            switch self {
            case .modelLoadFailed(let error):
                return "Failed to load WhisperKit model: \(error.localizedDescription)"
            case .transcriptionFailed(let error):
                return "Transcription failed: \(error.localizedDescription)"
            case .invalidAudioFile:
                return "The audio file is invalid or corrupted."
            case .modelNotAvailable:
                return "WhisperKit model is not available."
            }
        }
    }

    private(set) var modelState: ModelState = .notLoaded
    private var whisperKit: WhisperKit?

    var isModelReady: Bool {
        if case .loaded = modelState {
            return true
        }
        return false
    }

    // Load the WhisperKit model
    func loadModel() async throws {
        logger.info("🔄 Loading WhisperKit model...")

        // Don't reload if already loaded or loading
        switch modelState {
        case .loaded:
            logger.info("✅ Model already loaded")
            return
        case .loading:
            logger.info("⏳ Model already loading")
            return
        default:
            break
        }

        modelState = .loading
        logger.info("⬇️ Downloading/initializing WhisperKit 'base' model...")

        do {
            // Use the base model for good balance of speed and accuracy
            // Options: "tiny", "base", "small", "medium", "large"
            // For on-device transcription, "base" is a good starting point
            whisperKit = try await WhisperKit(model: "base")
            modelState = .loaded
            logger.info("✅ WhisperKit model loaded successfully")
        } catch {
            logger.error("❌ WhisperKit model loading failed: \(error.localizedDescription)")
            modelState = .failed(error)
            throw TranscriptionError.modelLoadFailed(error)
        }
    }

    // Transcribe an audio file to text
    func transcribe(audioURL: URL) async throws -> String {
        logger.info("🎤 Starting transcription for: \(audioURL.lastPathComponent)")

        // Ensure model is loaded
        if !isModelReady {
            logger.info("⚠️ Model not ready, loading now...")
            try await loadModel()
        }

        guard let whisperKit = whisperKit else {
            logger.error("❌ WhisperKit instance is nil")
            throw TranscriptionError.modelNotAvailable
        }

        // Check if file exists
        let fileExists = FileManager.default.fileExists(atPath: audioURL.path)
        logger.info("📁 Audio file exists: \(fileExists) at \(audioURL.path)")

        if fileExists {
            let fileSize = (try? FileManager.default.attributesOfItem(atPath: audioURL.path)[.size] as? Int64) ?? 0
            logger.info("📊 Audio file size: \(fileSize) bytes")
        }

        do {
            logger.info("🔄 Calling WhisperKit transcribe...")
            // Transcribe the audio file
            let results = try await whisperKit.transcribe(audioPath: audioURL.path)
            logger.info("✅ WhisperKit returned \(results.count) result(s)")

            // Extract the transcribed text from all segments
            let transcription = results.map { $0.text }.joined(separator: " ")
            logger.info("📝 Raw transcription length: \(transcription.count) characters")

            // If transcription is empty, return a default message
            let trimmed = transcription.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            if trimmed.isEmpty {
                logger.warning("⚠️ Transcription is empty - no speech detected")
                return "No speech detected in recording."
            }

            logger.info("✅ Transcription successful: \(trimmed.count) characters")
            return trimmed

        } catch {
            logger.error("❌ Transcription failed: \(error.localizedDescription)")
            throw TranscriptionError.transcriptionFailed(error)
        }
    }

    // Transcribe with progress updates (for future use)
    func transcribe(
        audioURL: URL,
        progressCallback: @escaping (Double) -> Void
    ) async throws -> String {
        // For now, just call the basic transcribe method
        // WhisperKit supports streaming, which could be integrated here
        return try await transcribe(audioURL: audioURL)
    }

    // Unload the model to free memory
    func unloadModel() {
        whisperKit = nil
        modelState = .notLoaded
    }
}
