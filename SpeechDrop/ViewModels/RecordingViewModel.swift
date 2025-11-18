import Foundation
import SwiftUI
import Dependencies

@MainActor
@Observable
final class RecordingViewModel {
    enum RecordingPhase: Equatable {
        case ready
        case recording
        case paused
        case processing
        case completed(JournalEntry)
        case failed(Error)

        static func == (lhs: RecordingPhase, rhs: RecordingPhase) -> Bool {
            switch (lhs, rhs) {
            case (.ready, .ready),
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

    private(set) var phase: RecordingPhase = .ready
    private(set) var recordingDuration: TimeInterval = 0
    private(set) var audioLevel: Float = 0.0

    private let audioService: AudioRecordingService
    private let transcriptionService: TranscriptionService
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

    // MARK: - Recording Controls

    func startRecording() async {
        do {
            try await audioService.startRecording()
            phase = .recording
            startUpdatingMetrics()
        } catch {
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
        guard let result = audioService.stopRecording() else {
            phase = .failed(AudioRecordingService.RecordingError.noActiveRecording)
            return
        }

        stopUpdatingMetrics()
        phase = .processing

        do {
            // Transcribe the audio
            let transcription = try await transcriptionService.transcribe(audioURL: result.url)

            // Create journal entry
            let entry = try journalViewModel.createEntryFromRecording(
                audioPath: result.url.path,
                transcription: transcription,
                duration: result.duration,
                fileSize: result.fileSize
            )

            // Select the newly created entry
            journalViewModel.selectedEntry = entry

            phase = .completed(entry)
        } catch {
            // Clean up the audio file if transcription/creation failed
            try? audioService.deleteRecording(at: result.url)
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
