import Foundation
import SQLiteData
import GRDB

@Table
struct JournalEntry: Sendable, Equatable, Identifiable, Hashable {
    var id: Int64?
    var title: String
    var transcription: String
    var createdAt: Date
    var updatedAt: Date
    var audioPath: String?
    var duration: TimeInterval
    var audioFileSize: Int64

    init(
        id: Int64? = nil,
        title: String = "",
        transcription: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        audioPath: String? = nil,
        duration: TimeInterval = 0,
        audioFileSize: Int64 = 0
    ) {
        self.id = id
        self.title = title
        self.transcription = transcription
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.audioPath = audioPath
        self.duration = duration
        self.audioFileSize = audioFileSize
    }
}

// MARK: - GRDB Integration
extension JournalEntry: FetchableRecord, MutablePersistableRecord {
    // Override the @Table macro's default pluralized name
    static let databaseTableName = "journalEntries"

    enum Columns: String, ColumnExpression, CodingKey {
        case id, title, transcription, createdAt, updatedAt, audioPath, duration, audioFileSize
    }

    // Decoding (FetchableRecord)
    nonisolated init(row: Row) throws {
        id = row[Columns.id]
        title = row[Columns.title]
        transcription = row[Columns.transcription]
        createdAt = row[Columns.createdAt]
        updatedAt = row[Columns.updatedAt]
        audioPath = row[Columns.audioPath]
        duration = row[Columns.duration]
        audioFileSize = row[Columns.audioFileSize]
    }

    // Encoding (EncodableRecord)
    nonisolated func encode(to container: inout PersistenceContainer) {
        container[Columns.id] = id
        container[Columns.title] = title
        container[Columns.transcription] = transcription
        container[Columns.createdAt] = createdAt
        container[Columns.updatedAt] = updatedAt
        container[Columns.audioPath] = audioPath
        container[Columns.duration] = duration
        container[Columns.audioFileSize] = audioFileSize
    }

    // Called after successful insertion - sets the auto-generated ID
    nonisolated mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

// MARK: - Computed Properties
extension JournalEntry {
    var wordCount: Int {
        let words = transcription.components(separatedBy: .whitespacesAndNewlines)
        return words.filter { !$0.isEmpty }.count
    }

    var characterCount: Int {
        transcription.count
    }

    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: audioFileSize)
    }

    var displayTitle: String {
        if title.isEmpty {
            return "Untitled Entry"
        }
        return title
    }
}
