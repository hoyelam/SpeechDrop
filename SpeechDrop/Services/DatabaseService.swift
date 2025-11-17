import Foundation
import SQLiteData
import GRDB
import Dependencies

// MARK: - Database Setup
func appDatabase() throws -> DatabaseQueue {
    let fileManager = FileManager.default
    let appSupportURL = try fileManager.url(
        for: .applicationSupportDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: true
    )

    let bundleID = Bundle.main.bundleIdentifier ?? "com.speechdrop"
    let appDirectory = appSupportURL.appendingPathComponent(bundleID, isDirectory: true)

    try fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true)

    let databaseURL = appDirectory.appendingPathComponent("speechdrop.db")

    let database = try DatabaseQueue(path: databaseURL.path)

    // Set up database schema with migrations
    var migrator = DatabaseMigrator()

    // Migration v1: Create journalEntries table
    migrator.registerMigration("createJournalEntries") { db in
        try db.create(table: JournalEntry.databaseTableName, ifNotExists: true) { t in
            t.column(JournalEntry.Columns.id.rawValue, .blob).notNull().primaryKey()
            t.column(JournalEntry.Columns.title.rawValue, .text).notNull()
            t.column(JournalEntry.Columns.transcription.rawValue, .text).notNull()
            t.column(JournalEntry.Columns.createdAt.rawValue, .datetime).notNull()
            t.column(JournalEntry.Columns.updatedAt.rawValue, .datetime).notNull()
            t.column(JournalEntry.Columns.audioPath.rawValue, .text)
            t.column(JournalEntry.Columns.duration.rawValue, .double).notNull()
            t.column(JournalEntry.Columns.audioFileSize.rawValue, .integer).notNull()
        }

        // Add indices for performance
        try db.create(
            index: "journalEntries_on_createdAt",
            on: JournalEntry.databaseTableName,
            columns: [JournalEntry.Columns.createdAt.rawValue]
        )

        try db.create(
            index: "journalEntries_on_title",
            on: JournalEntry.databaseTableName,
            columns: [JournalEntry.Columns.title.rawValue]
        )
    }

    // Run migrations
    try migrator.migrate(database)

    print("Database initialized at: \(databaseURL.path)")
    return database
}

// MARK: - Sample Data
func insertSampleData(into database: DatabaseQueue) async throws {
    // Check if data already exists
    let count = try await database.read { db in
        try JournalEntry.fetchCount(db)
    }

    guard count == 0 else {
        print("Sample data already exists")
        return
    }

    let sampleEntries = [
        JournalEntry(
            title: "Morning Thoughts",
            transcription: "Today started with a beautiful sunrise. I'm feeling grateful for the opportunity to work on this project. The weather is perfect, and I'm ready to tackle the day ahead.",
            createdAt: Date().addingTimeInterval(-86400 * 5),
            updatedAt: Date().addingTimeInterval(-86400 * 5),
            duration: 45,
            audioFileSize: 1_024_000
        ),
        JournalEntry(
            title: "Project Ideas",
            transcription: "I've been thinking about the architecture of the app. Using SwiftUI with SQLiteData makes sense. WhisperKit will handle the speech recognition. The three-panel layout will give users a professional experience similar to Xcode.",
            createdAt: Date().addingTimeInterval(-86400 * 3),
            updatedAt: Date().addingTimeInterval(-86400 * 3),
            duration: 62,
            audioFileSize: 1_536_000
        ),
        JournalEntry(
            title: "Daily Reflection",
            transcription: "Taking time to reflect on the progress made this week. It's important to celebrate small wins and learn from challenges. Tomorrow I'll focus on implementing the recording feature.",
            createdAt: Date().addingTimeInterval(-86400 * 1),
            updatedAt: Date().addingTimeInterval(-86400 * 1),
            duration: 38,
            audioFileSize: 896_000
        ),
        JournalEntry(
            title: "Quick Note",
            transcription: "Remember to buy groceries and call the dentist.",
            createdAt: Date().addingTimeInterval(-3600),
            updatedAt: Date().addingTimeInterval(-3600),
            duration: 5,
            audioFileSize: 128_000
        ),
        JournalEntry(
            title: "Evening Journal",
            transcription: "What a productive day! Completed the UI implementation for SpeechDrop. The three-panel layout looks great and functions smoothly. Next steps include integrating WhisperKit for actual speech recognition and adding more polish to the interface.",
            createdAt: Date(),
            updatedAt: Date(),
            duration: 52,
            audioFileSize: 1_280_000
        )
    ]

    try await database.write { db in
        for var entry in sampleEntries {
            try entry.insert(db)
        }
    }

    print("Inserted \(sampleEntries.count) sample journal entries")
}
