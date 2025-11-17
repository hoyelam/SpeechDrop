import SwiftUI
import SQLiteData
import GRDB
import Dependencies

struct SidebarView: View {
    @Bindable var viewModel: JournalViewModel
    @State private var searchText = ""

    // Use @FetchAll for reactive database updates
    @FetchAll(
        JournalEntry.order { $0.createdAt.desc() }
    )
    private var entries: [JournalEntry]

    var body: some View {
        List(selection: $viewModel.selectedEntry) {
            ForEach(filteredEntries) { entry in
                NavigationLink(value: entry) {
                    EntryRowView(entry: entry)
                }
            }
            .onDelete { offsets in
                try? viewModel.deleteEntries(at: offsets, from: filteredEntries)
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
