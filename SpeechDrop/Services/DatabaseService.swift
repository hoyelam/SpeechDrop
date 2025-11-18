import Foundation
import SQLiteData
import GRDB
import Dependencies
import OSLog

// MARK: - Logger
nonisolated(unsafe) private let logger = Logger(subsystem: "com.speechdrop", category: "database")

// MARK: - Database Setup
func appDatabase() throws -> any DatabaseWriter {
    @Dependency(\.context) var context

    // Configure database with query tracing
    var configuration = Configuration()

    // Enable query tracing in DEBUG mode
    #if DEBUG
    configuration.prepareDatabase { db in
        db.trace { event in
            if case let .statement(statement) = event {
                logger.debug("\(statement.sql)")
            }
        }
    }
    #endif

    // Create database using defaultDatabase helper
    let database = try defaultDatabase(configuration: configuration)

    // Set up database schema with migrations
    var migrator = DatabaseMigrator()

    #if DEBUG
    migrator.eraseDatabaseOnSchemaChange = true
    #endif

    // Migration v1: Create journalEntries table with auto-increment ID
    migrator.registerMigration("v1_createJournalEntries") { db in
        try #sql(
            """
            CREATE TABLE "\(raw: JournalEntry.databaseTableName)" (
                "id" INTEGER PRIMARY KEY AUTOINCREMENT,
                "title" TEXT NOT NULL DEFAULT '',
                "transcription" TEXT NOT NULL DEFAULT '',
                "createdAt" REAL NOT NULL,
                "updatedAt" REAL NOT NULL,
                "audioPath" TEXT,
                "duration" REAL NOT NULL DEFAULT 0,
                "audioFileSize" INTEGER NOT NULL DEFAULT 0
            )
            """
        )
        .execute(db)

        try #sql(
            """
            CREATE INDEX "journalEntries_on_createdAt"
            ON "\(raw: JournalEntry.databaseTableName)"("createdAt")
            """
        )
        .execute(db)

        try #sql(
            """
            CREATE INDEX "journalEntries_on_title"
            ON "\(raw: JournalEntry.databaseTableName)"("title")
            """
        )
        .execute(db)

        logger.info("Created journalEntries table with indices")
    }

    // Run migrations
    try migrator.migrate(database)

    logger.info("Database initialized successfully")
    return database
}

// MARK: - Sample Data
func insertSampleData(into database: any DatabaseWriter) async throws {
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
