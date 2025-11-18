import Foundation
import SQLiteData
import GRDB
import Dependencies

@Observable
@MainActor
final class JournalViewModel {
    var selectedEntry: JournalEntry?
    var searchText: String = ""

    @ObservationIgnored
    @Dependency(\.defaultDatabase) private var database

    init() {}

    // MARK: - CRUD Operations

    /// Create a new journal entry
    func createEntry(_ entry: JournalEntry) throws {
        var mutableEntry = entry
        try database.write { db in
            try mutableEntry.insert(db)
        }
    }

    /// Update an existing journal entry
    func updateEntry(_ entry: JournalEntry) throws {
        var updatedEntry = entry
        updatedEntry.updatedAt = Date()
        try database.write { db in
            try updatedEntry.update(db)
        }
    }

    /// Delete a single journal entry
    func deleteEntry(_ entry: JournalEntry) throws {
        try database.write { db in
            _ = try entry.delete(db)
        }
    }

    /// Delete multiple entries by index
    func deleteEntries(at offsets: IndexSet, from entries: [JournalEntry]) throws {
        try database.write { db in
            for index in offsets {
                var entryToDelete = entries[index]
                _ = try entryToDelete.delete(db)
            }
        }
    }

    // MARK: - Recording Workflow

    /// Create a new journal entry from a voice recording
    func createEntryFromRecording(
        audioPath: String,
        transcription: String,
        duration: TimeInterval,
        fileSize: Int64
    ) throws -> JournalEntry {
        // Generate title from transcription or use timestamp
        let title = generateTitleFromTranscription(transcription)

        let entry = JournalEntry(
            title: title,
            transcription: transcription,
            createdAt: Date(),
            updatedAt: Date(),
            audioPath: audioPath,
            duration: duration,
            audioFileSize: fileSize
        )

        var mutableEntry = entry
        try database.write { db in
            try mutableEntry.insert(db)
        }

        return mutableEntry
    }

    /// Delete an entry and its associated audio file
    func deleteEntryWithAudio(_ entry: JournalEntry) throws {
        // Delete audio file if it exists
        if let audioPath = entry.audioPath {
            let audioURL = URL(fileURLWithPath: audioPath)
            try? FileManager.default.removeItem(at: audioURL)
        }

        // Delete database entry
        try deleteEntry(entry)
    }

    // MARK: - Private Helpers

    private func generateTitleFromTranscription(_ transcription: String) -> String {
        // Try to use the first line or first sentence as title
        let trimmed = transcription.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            // Use timestamp if no transcription
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            return "Recording \(formatter.string(from: Date()))"
        }

        // Get first line or first sentence (up to 100 characters)
        let lines = trimmed.components(separatedBy: .newlines)
        if let firstLine = lines.first, !firstLine.isEmpty {
            return String(firstLine.prefix(100))
        }

        // Fall back to first 100 characters
        return String(trimmed.prefix(100))
    }
}
