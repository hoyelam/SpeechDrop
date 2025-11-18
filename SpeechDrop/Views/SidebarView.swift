import SwiftUI
import SQLiteData
import GRDB
import Dependencies

struct SidebarView: View {
    @Bindable var viewModel: JournalViewModel
    @State private var searchText = ""
    @State private var showingRecordingSheet = false

    // Use @FetchAll for reactive database updates
    @FetchAll(
        JournalEntry.order { $0.createdAt.desc() }
    )
    private var entries: [JournalEntry]

    var body: some View {
        VStack(spacing: 0) {
            // Journal entries list
            List(selection: $viewModel.selectedEntry) {
                ForEach(filteredEntries) { entry in
                    NavigationLink(value: entry) {
                        EntryRowView(entry: entry)
                    }
                }
                .onDelete { offsets in
                    deleteEntries(at: offsets)
                }
            }
            .navigationTitle("Journal Entries")
            .searchable(text: $searchText, prompt: "Search entries")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        createNewEntry()
                    } label: {
                        Label("New Entry", systemImage: "plus")
                    }
                }
            }

            // Prominent record button at bottom
            VStack(spacing: 12) {
                Divider()

                Button {
                    showingRecordingSheet = true
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(.red)
                                .frame(width: 36, height: 36)

                            Circle()
                                .fill(.white)
                                .frame(width: 16, height: 16)
                        }

                        Text("New Recording")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .padding(.horizontal)
                .padding(.bottom, 12)
            }
            .background(.background)
        }
        .sheet(isPresented: $showingRecordingSheet) {
            RecordingView(viewModel: RecordingViewModel(journalViewModel: viewModel))
        }
    }

    private var filteredEntries: [JournalEntry] {
        if searchText.isEmpty {
            return entries
        }
        return entries.filter { entry in
            entry.title.localizedCaseInsensitiveContains(searchText) ||
            entry.transcription.localizedCaseInsensitiveContains(searchText)
        }
    }

    private func createNewEntry() {
        let newEntry = JournalEntry(
            title: "New Entry",
            transcription: "",
            createdAt: Date(),
            updatedAt: Date()
        )
        try? viewModel.createEntry(newEntry)
        viewModel.selectedEntry = newEntry
    }

    private func deleteEntries(at offsets: IndexSet) {
        for index in offsets {
            let entry = filteredEntries[index]
            // Use deleteEntryWithAudio to clean up audio files
            if entry.audioPath != nil {
                try? viewModel.deleteEntryWithAudio(entry)
            } else {
                try? viewModel.deleteEntry(entry)
            }
        }
    }
}

struct EntryRowView: View {
    let entry: JournalEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.displayTitle)
                .font(.headline)
                .lineLimit(1)

            Text(entry.transcription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack {
                Text(entry.createdAt, style: .date)
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                Spacer()

                Text("\(entry.wordCount) words")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}
