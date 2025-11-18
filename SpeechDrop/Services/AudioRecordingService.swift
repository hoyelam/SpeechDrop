import Foundation
import AVFoundation
import Dependencies

@MainActor
@Observable
final class AudioRecordingService {
    enum RecordingState {
        case idle
        case recording
        case paused
        case stopped
    }

    enum RecordingError: LocalizedError {
        case permissionDenied
        case recordingFailed(Error)
        case fileCreationFailed
        case noActiveRecording

        var errorDescription: String? {
            switch self {
            case .permissionDenied:
                return "Microphone permission denied. Please enable microphone access in System Settings."
            case .recordingFailed(let error):
                return "Recording failed: \(error.localizedDescription)"
            case .fileCreationFailed:
                return "Failed to create audio file."
            case .noActiveRecording:
                return "No active recording session."
            }
        }
    }

    private(set) var state: RecordingState = .idle
    private(set) var currentRecordingURL: URL?
    private(set) var recordingDuration: TimeInterval = 0
    private(set) var audioLevel: Float = 0.0

    private var audioRecorder: AVAudioRecorder?
    private var meteringTimer: Timer?

    // Directory for storing audio recordings
    private var recordingsDirectory: URL {
        get throws {
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let recordingsPath = documentsPath.appendingPathComponent("Recordings", isDirectory: true)

            // Create directory if it doesn't exist
            try FileManager.default.createDirectory(at: recordingsPath, withIntermediateDirectories: true)

            return recordingsPath
        }
    }

    // MARK: - Recording Controls

    func startRecording() async throws {
        // Request permission (macOS handles this automatically via first use)
        #if os(iOS)
        let permitted = await requestMicrophonePermission()
        guard permitted else {
            throw RecordingError.permissionDenied
        }
        #endif

        // Generate unique filename
        let filename = "recording_\(Date().timeIntervalSince1970).wav"
        let recordingURL = try recordingsDirectory.appendingPathComponent(filename)

        // Configure recording settings for WAV format
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000.0, // WhisperKit works well with 16kHz
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: recordingURL, settings: settings)
            audioRecorder?.isMeteringEnabled = true

            guard audioRecorder?.record() == true else {
                throw RecordingError.fileCreationFailed
            }

            currentRecordingURL = recordingURL
            state = .recording
            recordingDuration = 0

            // Start metering timer
            startMetering()

        } catch {
            throw RecordingError.recordingFailed(error)
        }
    }

    func pauseRecording() {
        guard state == .recording else { return }
        audioRecorder?.pause()
        state = .paused
        stopMetering()
    }

    func resumeRecording() {
        guard state == .paused else { return }
        audioRecorder?.record()
        state = .recording
        startMetering()
    }

    func stopRecording() -> RecordingResult? {
        guard let recorder = audioRecorder,
              let url = currentRecordingURL else {
            return nil
        }

        recorder.stop()
        stopMetering()

        let duration = recorder.currentTime
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0

        state = .stopped
        audioRecorder = nil

        return RecordingResult(
            url: url,
            duration: duration,
            fileSize: fileSize
        )
    }

    func cancelRecording() {
        guard let recorder = audioRecorder,
              let url = currentRecordingURL else {
            return
        }

        recorder.stop()
        stopMetering()

        // Delete the recording file
        try? FileManager.default.removeItem(at: url)

        state = .idle
        audioRecorder = nil
        currentRecordingURL = nil
        recordingDuration = 0
    }

    // MARK: - Audio Level Metering

    private func startMetering() {
        meteringTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.updateMeters()
            }
        }
    }

    private func stopMetering() {
        meteringTimer?.invalidate()
        meteringTimer = nil
        audioLevel = 0.0
    }

    private func updateMeters() {
        guard let recorder = audioRecorder else { return }

        recorder.updateMeters()
        recordingDuration = recorder.currentTime

        // Get average power for the channel (normalized 0.0 to 1.0)
        let power = recorder.averagePower(forChannel: 0)
        // Convert from dB (-160 to 0) to linear scale (0.0 to 1.0)
        let normalizedPower = pow(10, power / 20)
        audioLevel = normalizedPower
    }

    // MARK: - Permissions

    #if os(iOS)
    private func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
    #endif

    // MARK: - File Management

    func deleteRecording(at url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }
}

// MARK: - Recording Result

struct RecordingResult {
    let url: URL
    let duration: TimeInterval
    let fileSize: Int64
}
