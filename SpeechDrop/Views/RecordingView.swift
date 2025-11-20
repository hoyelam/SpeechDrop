import SwiftUI

struct RecordingView: View {
    @Bindable var viewModel: RecordingViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingError = false
    @State private var errorMessage = ""

    var body: some View {
        VStack(spacing: 40) {
            // Header
            HStack {
                Button("Cancel") {
                    handleCancel()
                }
                .keyboardShortcut(.escape, modifiers: [])

                Spacer()

                if viewModel.canStop {
                    Button("Done") {
                        Task {
                            await viewModel.stopAndProcess()
                        }
                    }
                    .keyboardShortcut(.return, modifiers: [.command])
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()

            Spacer()

            // Content based on phase
            if case .loadingModel = viewModel.phase {
                VStack(spacing: 20) {
                    ProgressView()
                        .controlSize(.large)
                        .scaleEffect(1.5)

                    Text("Loading speech recognition model...")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    if case .loading = viewModel.transcriptionService.modelState {
                        Text("This may take a minute on first launch")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(height: 200)
            } else if viewModel.isProcessing {
                VStack(spacing: 20) {
                    ProgressView()
                        .controlSize(.large)
                        .scaleEffect(1.5)

                    Text("Transcribing audio...")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .frame(height: 200)
            } else {
                // Waveform visualization
                WaveformView(audioLevel: viewModel.audioLevel)
                    .frame(height: 100)
                    .padding(.horizontal, 40)

                // Recording duration
                Text(viewModel.formattedDuration)
                    .font(.system(size: 48, weight: .thin, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(viewModel.isRecording ? .red : .primary)

                // Status text
                Text(statusText)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Recording controls
            HStack(spacing: 40) {
                // Pause/Resume button (only visible when recording or paused)
                if viewModel.isRecording || viewModel.isPaused {
                    Button {
                        if viewModel.isRecording {
                            viewModel.pauseRecording()
                        } else {
                            viewModel.resumeRecording()
                        }
                    } label: {
                        Image(systemName: viewModel.isRecording ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                // Main record button
                Button {
                    handleRecordButtonTap()
                } label: {
                    ZStack {
                        Circle()
                            .fill(recordButtonColor)
                            .frame(width: 80, height: 80)

                        if viewModel.isRecording {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.white)
                                .frame(width: 32, height: 32)
                        } else if viewModel.canRecord {
                            Circle()
                                .fill(.white)
                                .frame(width: 32, height: 32)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isProcessing)
                .opacity(viewModel.isProcessing ? 0.5 : 1.0)
            }
            .padding(.bottom, 60)
        }
        .frame(minWidth: 500, minHeight: 500)
        .onChange(of: viewModel.phase) { _, newPhase in
            if case .completed = newPhase {
                dismiss()
            } else if case .failed(let error) = newPhase {
                // Show error alert
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
        .alert("Recording Error", isPresented: $showingError) {
            Button("OK") {
                viewModel.reset()
            }
        } message: {
            Text(errorMessage)
        }
        .task {
            // First ensure the model is loaded
            await viewModel.ensureModelLoaded()

            // Then start recording if we're ready
            if viewModel.canRecord {
                await viewModel.startRecording()
            }
        }
    }

    private var statusText: String {
        switch viewModel.phase {
        case .loadingModel:
            return "Loading model..."
        case .ready:
            return "Ready to record"
        case .recording:
            return "Recording..."
        case .paused:
            return "Paused"
        case .processing:
            return "Transcribing..."
        case .completed:
            return "Complete"
        case .failed(let error):
            return "Error: \(error.localizedDescription)"
        }
    }

    private var recordButtonColor: Color {
        if viewModel.isRecording {
            return .red
        } else {
            return .gray.opacity(0.3)
        }
    }

    private func handleRecordButtonTap() {
        if viewModel.canRecord {
            Task {
                await viewModel.startRecording()
            }
        } else if viewModel.canStop {
            Task {
                await viewModel.stopAndProcess()
            }
        }
    }

    private func handleCancel() {
        viewModel.cancel()
        dismiss()
    }
}

// MARK: - Waveform Visualization

struct WaveformView: View {
    let audioLevel: Float
    private let barCount = 40

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(barColor(for: index))
                    .frame(width: 4)
                    .frame(height: barHeight(for: index))
            }
        }
    }

    private func barHeight(for index: Int) -> CGFloat {
        // Create a wave pattern based on audio level
        let normalizedIndex = CGFloat(index) / CGFloat(barCount)
        let baseHeight: CGFloat = 20

        // Simulate wave pattern with varying heights
        let wavePattern = sin(normalizedIndex * .pi * 4) * 0.3 + 0.7

        // Multiply by audio level for reactive animation
        let height = baseHeight + (wavePattern * CGFloat(audioLevel) * 80)

        return max(baseHeight, height)
    }

    private func barColor(for index: Int) -> Color {
        let intensity = barHeight(for: index) / 100
        return Color.red.opacity(Double(0.3 + intensity * 0.7))
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var viewModel = RecordingViewModel(
        journalViewModel: JournalViewModel()
    )

    RecordingView(viewModel: viewModel)
}
