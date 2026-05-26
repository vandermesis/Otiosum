import SwiftData

// MARK: - Schema V1 (baseline captured 2026-05-27)
//
// Every @Model class must appear here, even if it hasn't changed.
// Each VersionedSchema is a complete snapshot, not a diff.
//
// To add a new schema version:
//   1. Add OtiosumSchemaV2 (nest frozen copies of changed model definitions there)
//   2. Update the top-level @Model classes with the new properties
//   3. Add a MigrationStage (lightweight or custom) to OtiosumMigrationPlan.stages
//   4. Append OtiosumSchemaV2 to OtiosumMigrationPlan.schemas
//   NEVER modify this V1 definition after shipping — it is the upgrade anchor.

enum OtiosumSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Event.self,
            CalendarLink.self,
            DayTemplate.self,
            DailyBudget.self,
            IconCatalogSymbol.self,
            Item.self
        ]
    }
}

// MARK: - Migration Plan

enum OtiosumMigrationPlan: SchemaMigrationPlan {
    /// All schema versions in ascending order. Append new versions here.
    static var schemas: [any VersionedSchema.Type] {
        [OtiosumSchemaV1.self]
    }

    /// Migration stages between consecutive versions.
    /// Empty now — add a stage whenever OtiosumSchemaV2 is introduced.
    static var stages: [MigrationStage] { [] }
}
