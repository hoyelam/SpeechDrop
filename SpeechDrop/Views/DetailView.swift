import SwiftUI

struct DetailView: View {
    @Binding var entry: JournalEntry?
    let viewModel: JournalViewModel

    var body: some View {
        if let entry {
            EntryDetailView(entry: entry, viewModel: viewModel)
        } else {
            ContentUnavailableView(
                "No Entry Selected",
                systemImage: "doc.text",
                description: Text("Select an entry from the sidebar or create a new one")
            )
        }
    }
}

struct EntryDetailView: View {
    var entry: JournalEntry
    let viewModel: JournalViewModel

    @State private var editedTitle: String
    @State private var editedTranscription: String

    init(entry: JournalEntry, viewModel: JournalViewModel) {
        self.entry = entry
        self.viewModel = viewModel
        _editedTitle = State(initialValue: entry.title)
        _editedTranscription = State(initialValue: entry.transcription)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title Section
            VStack(alignment: .leading, spacing: 8) {
                TextField("Title", text: $editedTitle, axis: .vertical)
                    .font(.title2.bold())
                    .textFieldStyle(.plain)
                    .onChange(of: editedTitle) {
                        saveChanges()
                    }

                HStack {
                    Label(
                        entry.createdAt.formatted(date: .abbreviated, time: .shortened),
                        systemImage: "calendar"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    Spacer()

                    if entry.updatedAt != entry.createdAt {
                        Text("Edited \(entry.updatedAt.formatted(.relative(presentation: .named)))")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Transcription Editor
            ScrollView {
                TextEditor(text: $editedTranscription)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                    .onChange(of: editedTranscription) {
                        saveChanges()
                    }
            }
        }
        .onChange(of: entry) {
            editedTitle = entry.title
            editedTranscription = entry.transcription
        }
    }

    private func saveChanges() {
        var updatedEntry = entry
        updatedEntry.title = editedTitle
        updatedEntry.transcription = editedTranscription
        updatedEntry.updatedAt = Date()

        try? viewModel.updateEntry(updatedEntry)
    }
}
