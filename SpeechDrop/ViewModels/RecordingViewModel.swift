import Foundation
import SwiftUI
import Dependencies
import os.log

@MainActor
@Observable
final class RecordingViewModel {
    private let logger = Logger(subsystem: "com.kin-yee.SpeechDrop", category: "RecordingViewModel")
    enum RecordingPhase: Equatable {
        case loadingModel
        case ready
        case recording
        case paused
        case processing
        case completed(JournalEntry)
        case failed(Error)

        static func == (lhs: RecordingPhase, rhs: RecordingPhase) -> Bool {
            switch (lhs, rhs) {
            case (.loadingModel, .loadingModel),
                 (.ready, .ready),
                 (.recording, .recording),
                 (.paused, .paused),
                 (.processing, .processing):
                return true
            case (.completed(let lEntry), .completed(let rEntry)):
                return lEntry.id == rEntry.id
            case (.failed, .failed):
                return true
            default:
                return false
            }
        }
    }

    private(set) var phase: RecordingPhase = .loadingModel
    private(set) var recordingDuration: TimeInterval = 0
    private(set) var audioLevel: Float = 0.0

    private let audioService: AudioRecordingService
    let transcriptionService: TranscriptionService
    private let journalViewModel: JournalViewModel

    private var updateTimer: Timer?

    init(
        journalViewModel: JournalViewModel,
        audioService: AudioRecordingService? = nil,
        transcriptionService: TranscriptionService? = nil
    ) {
        self.journalViewModel = journalViewModel
        self.audioService = audioService ?? AudioRecordingService()
        self.transcriptionService = transcriptionService ?? TranscriptionService()
    }

    // MARK: - Model Loading

    func ensureModelLoaded() async {
        logger.info("🔄 Ensuring WhisperKit model is loaded...")
        guard !transcriptionService.isModelReady else {
            logger.info("✅ Model already loaded")
            phase = .ready
            return
        }

        phase = .loadingModel
        logger.info("⬇️ Loading WhisperKit model...")

        do {
            try await transcriptionService.loadModel()
            logger.info("✅ Model loaded successfully")
            phase = .ready
        } catch {
            logger.error("❌ Model loading failed: \(error.localizedDescription)")
            phase = .failed(error)
        }
    }

    // MARK: - Recording Controls

    func startRecording() async {
        logger.info("🎙️ Starting recording workflow...")
        do {
            try await audioService.startRecording()
            logger.info("✅ Audio service started recording")
            phase = .recording
            startUpdatingMetrics()
        } catch {
            logger.error("❌ Failed to start recording: \(error.localizedDescription)")
            phase = .failed(error)
        }
    }

    func pauseRecording() {
        audioService.pauseRecording()
        phase = .paused
        stopUpdatingMetrics()
    }

    func resumeRecording() {
        audioService.resumeRecording()
        phase = .recording
        startUpdatingMetrics()
    }

    func stopAndProcess() async {
        logger.info("⏹️ Stopping recording and processing...")
        guard let result = audioService.stopRecording() else {
            logger.error("❌ Failed to stop recording - no active recording")
            phase = .failed(AudioRecordingService.RecordingError.noActiveRecording)
            return
        }

        logger.info("📊 Recording result - duration: \(result.duration)s, size: \(result.fileSize) bytes")

        stopUpdatingMetrics()
        phase = .processing
        logger.info("🔄 Starting transcription...")

        do {
            // Transcribe the audio
            let transcription = try await transcriptionService.transcribe(audioURL: result.url)
            logger.info("✅ Transcription completed - length: \(transcription.count) characters")
            logger.debug("📝 Transcription preview: \(transcription.prefix(100))...")

            // Create journal entry
            let entry = try journalViewModel.createEntryFromRecording(
                audioPath: result.url.path,
                transcription: transcription,
                duration: result.duration,
                fileSize: result.fileSize
            )
            logger.info("✅ Journal entry created - ID: \(entry.id ?? -1), title: \(entry.title)")

            // Select the newly created entry
            journalViewModel.selectedEntry = entry
            logger.info("✅ Entry selected in sidebar")

            phase = .completed(entry)
            logger.info("✅ Recording workflow completed successfully")
        } catch {
            logger.error("❌ Processing failed: \(error.localizedDescription)")
            // Clean up the audio file if transcription/creation failed
            try? audioService.deleteRecording(at: result.url)
            logger.info("🗑️ Audio file cleaned up after failure")
            phase = .failed(error)
        }
    }

    func cancel() {
        audioService.cancelRecording()
        stopUpdatingMetrics()
        phase = .ready
    }

    func reset() {
        phase = .ready
        recordingDuration = 0
        audioLevel = 0.0
    }

    // MARK: - Metrics Updates

    private func startUpdatingMetrics() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.updateMetrics()
            }
        }
    }

    private func stopUpdatingMetrics() {
        updateTimer?.invalidate()
        updateTimer = nil
    }

    private func updateMetrics() {
        recordingDuration = audioService.recordingDuration
        audioLevel = audioService.audioLevel
    }

    // MARK: - Computed Properties

    var formattedDuration: String {
        let minutes = Int(recordingDuration) / 60
        let seconds = Int(recordingDuration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var isRecording: Bool {
        if case .recording = phase {
            return true
        }
        return false
    }

    var isPaused: Bool {
        if case .paused = phase {
            return true
        }
        return false
    }

    var isProcessing: Bool {
        if case .processing = phase {
            return true
        }
        return false
    }

    var canRecord: Bool {
        if case .ready = phase {
            return true
        }
        return false
    }

    var canPause: Bool {
        if case .recording = phase {
            return true
        }
        return false
    }

    var canResume: Bool {
        if case .paused = phase {
            return true
        }
        return false
    }

    var canStop: Bool {
        switch phase {
        case .recording, .paused:
            return true
        default:
            return false
        }
    }
}
