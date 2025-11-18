import SwiftUI

struct InspectorView: View {
    let entry: JournalEntry?

    var body: some View {
        if let entry {
            EntryInspectorView(entry: entry)
        } else {
            ContentUnavailableView(
                "No Selection",
                systemImage: "info.circle",
                description: Text("Select an entry to view details")
            )
        }
    }
}

struct EntryInspectorView: View {
    let entry: JournalEntry

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Text Statistics
                InspectorSection(title: "Text Statistics") {
                    InspectorRow(label: "Words", value: "\(entry.wordCount)")
                    InspectorRow(label: "Characters", value: "\(entry.characterCount)")
                    InspectorRow(label: "Lines", value: "\(lineCount)")
                }

                Divider()

                // Audio Information
                InspectorSection(title: "Audio Information") {
                    InspectorRow(label: "Duration", value: entry.formattedDuration)
                    InspectorRow(label: "File Size", value: entry.formattedFileSize)
                    if let audioPath = entry.audioPath {
                        InspectorRow(label: "Format", value: audioFileFormat(audioPath))
                    } else {
                        InspectorRow(label: "Audio File", value: "Not available")
                    }
                }

                Divider()

                // Dates
                InspectorSection(title: "Timeline") {
                    InspectorRow(
                        label: "Created",
                        value: entry.createdAt.formatted(date: .abbreviated, time: .shortened)
                    )
                    InspectorRow(
                        label: "Modified",
                        value: entry.updatedAt.formatted(date: .abbreviated, time: .shortened)
                    )
                }

                Divider()

                // Metadata
                InspectorSection(title: "Metadata") {
                    if let id = entry.id {
                        InspectorRow(label: "ID", value: "#\(id)")
                    }
                    InspectorRow(label: "Reading Time", value: estimatedReadingTime)
                }

                Spacer()
            }
            .padding()
        }
        .frame(minWidth: 200, idealWidth: 250)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var lineCount: Int {
        entry.transcription.components(separatedBy: .newlines).count
    }

    private var estimatedReadingTime: String {
        let wordsPerMinute = 200.0
        let minutes = Double(entry.wordCount) / wordsPerMinute
        if minutes < 1 {
            return "< 1 min"
        }
        return "\(Int(minutes.rounded())) min"
    }

    private func audioFileFormat(_ path: String) -> String {
        let url = URL(fileURLWithPath: path)
        let ext = url.pathExtension.uppercased()
        return ext.isEmpty ? "Unknown" : ext
    }
}

struct InspectorSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                content
            }
        }
    }
}

struct InspectorRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
    }
}
