# SQLiteData Agent Rules

## Overview

SQLiteData is a fast, lightweight replacement for SwiftData, powered by SQL and supporting CloudKit synchronization. It's built on top of the popular GRDB library and uses StructuredQueries for type-safe SQL query building with high-performance decoding.

**Key advantages over SwiftData:**
- Direct SQLite access with full SQL capabilities
- High-performance decoding (comparable to SQLite C APIs)
- CloudKit synchronization and sharing support
- Usable from SwiftUI, UIKit, @Observable models, and anywhere else
- Type-safe query building with compile-time safety
- More powerful querying than SwiftData's @Query

## Core Concepts

### Database Initialization

Initialize the database in your app's entry point using `prepareDependencies`:

```swift
@main
struct MyApp: App {
  init() {
    prepareDependencies {
      // Create/migrate a database connection
      let db = try! DatabaseQueue(/* ... */)
      $0.defaultDatabase = db
    }
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
    }
  }
}
```

### Accessing the Database

Access the database throughout your application using the `@Dependency` property wrapper:

```swift
@Dependency(\.defaultDatabase) var database

// Write to the database
try database.write { db in
  try Item.insert { Item(/* ... */) }
    .execute(db)
}
```

## Model Definition with @Table

Use the `@Table` macro to define your database models as structs (not classes):

```swift
@Table
struct Item {
  let id: UUID           // Immutable identifier
  var title = ""         // Default values supported
  var isInStock = true
  var notes = ""
}

@Table
struct Account {
  let id: UUID
  var name: String
  var type: AccountType  // Raw representable enums supported
  var balance: Decimal
  var lastUpdated: Date
}

enum AccountType: String, Codable {
  case cash
  case investment
  case property
}
```

**Best practices for @Table models:**
- Use `struct` (not `class`)
- Use `let` for identifiers (id, foreign keys)
- Use `var` for mutable fields
- Provide default values where appropriate
- Support raw representable enums
- Use Swift types that map to SQLite (String, Int, Double, Decimal, Date, UUID, Bool, Data)

## Fetching Data

### @FetchAll - Fetch Multiple Records

The `@FetchAll` property wrapper fetches an array of records and automatically updates when the database changes:

```swift
// Fetch all items
@FetchAll
var items: [Item]

// Fetch with ordering
@FetchAll(Item.order(by: \.title))
var itemsByTitle: [Item]

@FetchAll(Item.order(by: \.isInStock))
var itemsByStock: [Item]

// Fetch with filtering
@FetchAll(Item.where(\.isInStock))
var inStockItems: [Item]

@FetchAll(Item.where(\.type, .equalTo, "cash"))
var cashAccounts: [Account]

// Combine ordering and filtering
@FetchAll(
  Item
    .where(\.isInStock)
    .order(by: \.title)
)
var sortedInStockItems: [Item]
```

### @FetchOne - Fetch Single Record or Aggregate

The `@FetchOne` property wrapper fetches a single value:

```swift
// Count records
@FetchOne(Item.count())
var itemCount = 0

// Fetch single record
@FetchOne(Item.where(\.id, .equalTo, itemId))
var item: Item?

// Aggregate queries
@FetchOne(Account.select { $0.balance.sum() })
var totalBalance: Decimal = 0
```

### @Fetch - Advanced Custom Queries

Use `@Fetch` for more complex queries:

```swift
@Fetch(
  Item
    .select { ($0.title, $0.count()) }
    .group(by: \.isInStock)
)
var itemsByStockStatus: [(String, Int)]
```

## Query Building

SQLiteData uses StructuredQueries for type-safe SQL building:

### Filtering with .where()

```swift
// Single condition
Item.where(\.isInStock)
Item.where(\.title, .equalTo, "Example")
Item.where(\.balance, .greaterThan, 1000)

// Multiple conditions
Item
  .where(\.isInStock)
  .where(\.type, .equalTo, "cash")
```

### Ordering with .order()

```swift
// Ascending (default)
Item.order(by: \.title)
Item.order(by: \.createdAt)

// Descending
Item.order { $0.balance.desc() }
Item.order { $0.createdAt.desc() }
```

### Aggregations

```swift
// Count
Item.count()

// Sum
Account.select { $0.balance.sum() }

// Grouping
Item
  .select { ($0.type, $0.count()) }
  .group(by: \.type)
```

### Safe SQL with #sql Macro

For complex queries, use the `#sql` macro for safe SQL string interpolation:

```swift
let query = #sql("SELECT * FROM items WHERE title LIKE ?", "%\(searchTerm)%")
```

## Writing Data

Use database transactions for all write operations:

### Insert

```swift
@Dependency(\.defaultDatabase) var database

try database.write { db in
  try Item.insert {
    Item(
      id: UUID(),
      title: "New Item",
      isInStock: true,
      notes: ""
    )
  }
  .execute(db)
}
```

### Update

```swift
try database.write { db in
  try Item
    .where(\.id, .equalTo, itemId)
    .update {
      $0.title = "Updated Title"
      $0.isInStock = false
    }
    .execute(db)
}
```

### Delete

```swift
try database.write { db in
  try Item
    .where(\.id, .equalTo, itemId)
    .delete()
    .execute(db)
}
```

### Batch Operations

```swift
try database.write { db in
  // Insert multiple items
  for item in newItems {
    try Item.insert { item }.execute(db)
  }

  // Or use GRDB's batch insert
  try db.execute(sql: "INSERT INTO items ...")
}
```

## CloudKit Synchronization

### Setting Up SyncEngine

Enable CloudKit synchronization in your app's entry point:

```swift
@main
struct MyApp: App {
  init() {
    prepareDependencies {
      // Initialize database
      $0.defaultDatabase = try! appDatabase()

      // Enable CloudKit sync
      $0.defaultSyncEngine = SyncEngine(
        for: $0.defaultDatabase,
        tables: Item.self, Account.self  // Specify tables to sync
      )
    }
  }
}
```

### CloudKit Sharing

SQLiteData supports iCloud sharing, allowing users to share records with other iCloud users:

```swift
// Share a record
try await syncEngine.share(record: item)

// Accept a shared record
try await syncEngine.acceptShare(shareURL: url)
```

## SwiftUI Integration

SQLiteData property wrappers are automatically observed by SwiftUI:

```swift
struct ItemListView: View {
  @FetchAll(Item.order(by: \.title))
  var items: [Item]

  @Dependency(\.defaultDatabase)
  var database

  var body: some View {
    List(items, id: \.id) { item in
      ItemRow(item: item)
    }
    .toolbar {
      Button("Add Item") {
        addItem()
      }
    }
  }

  func addItem() {
    try? database.write { db in
      try Item.insert {
        Item(id: UUID(), title: "New Item")
      }
      .execute(db)
    }
  }
}
```

**Key points:**
- Views automatically update when database changes
- No need for `@State` or `@Published` for database-backed data
- Works with UIKit and @Observable models too

## Performance

SQLiteData leverages high-performance decoding from StructuredQueries:

**Performance characteristics:**
- Decoding comparable to invoking SQLite C APIs directly
- Significantly faster than SwiftData for large datasets
- Efficient memory usage with lazy loading support
- Optimized batch operations

**Benchmark comparison (Orders.fetchAll):**
```
SQLite (C APIs, Enlighter)     7.183ms
Lighter                        8.059ms
SQLiteData                     8.511ms  ← Competitive!
GRDB (manual decoding)        18.819ms
SQLite.swift (manual)         27.994ms
SQLite.swift (Codable)        43.261ms
GRDB (Codable)                53.326ms
```

## Best Practices

### Schema Design

- **Normalization**: Design normalized schemas to avoid data redundancy
- **Indices**: Create indices for frequently queried columns
- **Foreign keys**: Use foreign keys to maintain referential integrity
- **Migrations**: Plan schema migrations carefully using GRDB's migration APIs

```swift
func appDatabase() throws -> DatabaseQueue {
  let db = try DatabaseQueue(/* ... */)

  try db.write { db in
    // Create tables
    try db.create(table: "items") { t in
      t.column("id", .blob).notNull().primaryKey()
      t.column("title", .text).notNull()
      t.column("isInStock", .boolean).notNull()
      t.column("notes", .text).notNull()
    }

    // Add indices
    try db.create(index: "items_on_title", on: "items", columns: ["title"])
  }

  return db
}
```

### When to Use SQLiteData vs SwiftData

**Use SQLiteData when you need:**
- Full SQL capabilities (joins, complex queries, aggregations)
- Maximum performance
- CloudKit synchronization
- Fine-grained control over database schema
- Support for UIKit or non-SwiftUI contexts
- Advanced querying beyond SwiftData's limitations

**Use SwiftData when:**
- Building simple CRUD apps with basic queries
- You want Apple's native solution
- You don't need advanced SQL features
- The app requirements fit within SwiftData's capabilities

### Error Handling

Always handle database errors appropriately:

```swift
do {
  try database.write { db in
    try Item.insert { newItem }.execute(db)
  }
} catch {
  // Handle database error
  print("Failed to insert item: \(error)")
  // Show error to user
}
```

### Testing

Use in-memory databases for testing:

```swift
func testDatabase() throws -> DatabaseQueue {
  let db = try DatabaseQueue(configuration: .init())
  // Set up schema
  return db
}
```

## Integration with GRDB

SQLiteData is built on GRDB, so you can leverage GRDB's extensive APIs:

### Raw SQL Queries

```swift
try database.read { db in
  let rows = try Row.fetchAll(db, sql: "SELECT * FROM items WHERE title LIKE ?", arguments: ["%search%"])
}
```

### Custom Decoders

```swift
extension Item: FetchableRecord {
  init(row: Row) {
    id = row["id"]
    title = row["title"]
    isInStock = row["isInStock"]
    notes = row["notes"]
  }
}
```

### Observation

```swift
// Observe database changes
let observation = ValueObservation.tracking { db in
  try Item.fetchAll(db)
}

let cancellable = observation.start(in: database) { items in
  print("Items changed: \(items)")
}
```

## Common Patterns for GrowVault

### Modeling Financial Assets

```swift
@Table
struct Asset {
  let id: UUID
  var name: String
  var type: AssetType
  var value: Decimal
  var currency: String
  var lastUpdated: Date
}

@Table
struct Liability {
  let id: UUID
  var name: String
  var type: LiabilityType
  var amount: Decimal
  var currency: String
  var lastUpdated: Date
}
```

### Calculating Net Worth

```swift
@FetchOne(Asset.select { $0.value.sum() })
var totalAssets: Decimal = 0

@FetchOne(Liability.select { $0.amount.sum() })
var totalLiabilities: Decimal = 0

var netWorth: Decimal {
  totalAssets - totalLiabilities
}
```

### Recurring Entries

```swift
@Table
struct RecurringEntry {
  let id: UUID
  var assetId: UUID?
  var liabilityId: UUID?
  var frequency: RecurrenceFrequency
  var nextUpdate: Date
  var isActive: Bool
}

// Fetch due entries
@FetchAll(
  RecurringEntry
    .where(\.isActive)
    .where(\.nextUpdate, .lessThanOrEqualTo, Date())
)
var dueEntries: [RecurringEntry]
```

## Required Knowledge

To best use SQLiteData, you should understand:

1. **SQLite basics**: Schema design, normalization, queries
2. **SQL syntax**: SELECT, INSERT, UPDATE, DELETE, joins, aggregates
3. **Performance**: Indices, query optimization, transaction management
4. **GRDB**: For advanced features beyond StructuredQueries

## Resources

- **SQLiteData**: https://github.com/pointfreeco/sqlite-data
- **StructuredQueries**: https://github.com/pointfreeco/swift-structured-queries
- **GRDB**: https://github.com/groue/GRDB.swift
- **SQLite documentation**: https://www.sqlite.org/docs.html

## Summary

SQLiteData provides a powerful, type-safe, high-performance alternative to SwiftData with:
- `@Table` macro for defining models
- `@FetchAll`, `@FetchOne`, `@Fetch` for querying
- Type-safe query building with StructuredQueries
- Automatic SwiftUI observation
- CloudKit synchronization
- Full SQLite and GRDB capabilities

Use it to build robust, performant data-driven apps with complete control over your database schema and queries.
