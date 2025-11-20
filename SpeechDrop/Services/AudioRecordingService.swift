import Foundation
import AVFoundation
import Dependencies
import os.log

@MainActor
@Observable
final class AudioRecordingService {
    private let logger = Logger(subsystem: "com.kin-yee.SpeechDrop", category: "AudioRecording")
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
        logger.info("🎙️ Starting recording...")

        // Request permission (macOS handles this automatically via first use)
        #if os(iOS)
        logger.info("📱 iOS platform - requesting microphone permission")
        let permitted = await requestMicrophonePermission()
        guard permitted else {
            logger.error("❌ Microphone permission denied")
            throw RecordingError.permissionDenied
        }
        logger.info("✅ Microphone permission granted")
        #else
        logger.info("💻 macOS platform - microphone permission requested on first use")
        #endif

        // Generate unique filename
        let filename = "recording_\(Date().timeIntervalSince1970).wav"
        let recordingURL = try recordingsDirectory.appendingPathComponent(filename)
        logger.info("📁 Recording URL: \(recordingURL.path)")

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
        logger.info("⚙️ Recording settings: 16kHz, mono, 16-bit PCM")

        do {
            logger.info("🔧 Creating AVAudioRecorder...")
            audioRecorder = try AVAudioRecorder(url: recordingURL, settings: settings)
            audioRecorder?.isMeteringEnabled = true

            logger.info("▶️ Starting AVAudioRecorder...")
            guard audioRecorder?.record() == true else {
                logger.error("❌ AVAudioRecorder.record() returned false")
                throw RecordingError.fileCreationFailed
            }

            logger.info("✅ Recording started successfully")
            logger.info("📊 Initial recording state - isRecording: \(self.audioRecorder?.isRecording ?? false)")

            currentRecordingURL = recordingURL
            state = .recording
            recordingDuration = 0

            // Start metering timer
            startMetering()
            logger.info("📈 Metering timer started")

        } catch {
            logger.error("❌ Recording failed with error: \(error.localizedDescription)")
            throw RecordingError.recordingFailed(error)
        }
    }

    func pauseRecording() {
        logger.info("⏸️ Pausing recording...")
        guard state == .recording else {
            logger.warning("⚠️ Cannot pause - current state: \(String(describing: self.state))")
            return
        }
        audioRecorder?.pause()
        state = .paused
        stopMetering()
        logger.info("✅ Recording paused")
    }

    func resumeRecording() {
        logger.info("▶️ Resuming recording...")
        guard state == .paused else {
            logger.warning("⚠️ Cannot resume - current state: \(String(describing: self.state))")
            return
        }
        audioRecorder?.record()
        state = .recording
        startMetering()
        logger.info("✅ Recording resumed")
    }

    func stopRecording() -> RecordingResult? {
        logger.info("⏹️ Stopping recording...")
        guard let recorder = audioRecorder,
              let url = currentRecordingURL else {
            logger.error("❌ No active recording to stop")
            return nil
        }

        logger.info("📊 Final recording state - isRecording: \(recorder.isRecording)")
        logger.info("⏱️ Recording duration: \(recorder.currentTime)s")

        recorder.stop()
        stopMetering()

        let duration = recorder.currentTime
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0

        logger.info("📁 File size: \(fileSize) bytes")
        logger.info("📍 File path: \(url.path)")

        // Check if file exists
        let fileExists = FileManager.default.fileExists(atPath: url.path)
        logger.info("📂 File exists: \(fileExists)")

        state = .stopped
        audioRecorder = nil

        logger.info("✅ Recording stopped successfully")

        return RecordingResult(
            url: url,
            duration: duration,
            fileSize: fileSize
        )
    }

    func cancelRecording() {
        logger.info("🗑️ Cancelling recording...")
        guard let recorder = audioRecorder,
              let url = currentRecordingURL else {
            logger.warning("⚠️ No active recording to cancel")
            return
        }

        recorder.stop()
        stopMetering()

        // Delete the recording file
        try? FileManager.default.removeItem(at: url)
        logger.info("📁 Recording file deleted: \(url.path)")

        state = .idle
        audioRecorder = nil
        currentRecordingURL = nil
        recordingDuration = 0
        logger.info("✅ Recording cancelled")
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

        // Log periodically (every 2 seconds)
        if Int(self.recordingDuration) % 2 == 0 && self.recordingDuration > 0 {
            logger.debug("📊 Metering update - duration: \(String(format: "%.1f", self.recordingDuration))s, power: \(String(format: "%.2f", power))dB, normalized: \(String(format: "%.3f", normalizedPower))")
        }
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
