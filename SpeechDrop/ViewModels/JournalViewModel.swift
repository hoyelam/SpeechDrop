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
}
