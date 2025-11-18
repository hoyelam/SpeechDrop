import Foundation
import WhisperKit

@MainActor
final class TranscriptionService {
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

    private var whisperKit: WhisperKit?
    private var isModelLoaded = false

    // Load the WhisperKit model
    func loadModel() async throws {
        guard !isModelLoaded else { return }

        do {
            // Use the base model for good balance of speed and accuracy
            // Options: "tiny", "base", "small", "medium", "large"
            // For on-device transcription, "base" is a good starting point
            whisperKit = try await WhisperKit(model: "base")
            isModelLoaded = true
            print("WhisperKit model loaded successfully")
        } catch {
            throw TranscriptionError.modelLoadFailed(error)
        }
    }

    // Transcribe an audio file to text
    func transcribe(audioURL: URL) async throws -> String {
        // Ensure model is loaded
        if !isModelLoaded {
            try await loadModel()
        }

        guard let whisperKit = whisperKit else {
            throw TranscriptionError.modelNotAvailable
        }

        do {
            // Transcribe the audio file
            let results = try await whisperKit.transcribe(audioPath: audioURL.path)

            // Extract the transcribed text from all segments
            let transcription = results.map { $0.text }.joined(separator: " ")

            // If transcription is empty, return a default message
            let trimmed = transcription.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            if trimmed.isEmpty {
                return "No speech detected in recording."
            }

            return trimmed

        } catch {
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
        isModelLoaded = false
    }
}
