import Foundation
import SwiftData

// MARK: - WeekEntry
// ─────────────────────────────────────────────────────────────────────
// This is like a JPA @Entity in Spring Boot, but for on-device storage.
// In React, this was your `weeks` table in Supabase.
//
// SwiftData uses the @Model macro (like @Entity in JPA) to:
//   1. Auto-generate the database schema
//   2. Track changes (like Hibernate dirty checking)
//   3. Persist to SQLite under the hood
//
// Key difference from React: No manual JSON serialization.
// SwiftData handles Codable types natively.
// ─────────────────────────────────────────────────────────────────────

@Model
final class WeekEntry {
    // Primary key — the Monday date as "YYYY-MM-DD"
    // In your React app this was `id` in the weeks table.
    // @Attribute(.unique) is like @Id + @Column(unique=true) in JPA.
    @Attribute(.unique)
    var weekId: String

    // Raw daycare input per day — text pasted or "[Screenshot: filename]"
    // In React: entries["Monday"] = "pasted text..."
    // Swift dictionaries are Codable, so SwiftData stores them as JSON blobs.
    var entries: [String: String]

    // Claude-parsed structured data per day
    // In React: parsedEntries["Monday"] = { eating: {...}, naps: {...}, ... }
    var parsedEntries: [String: ParsedDayData]

    // Parent notes — before/after school context
    // In React: morningNotes["Monday"] = "Rough morning..."
    var morningNotes: [String: String]
    var eveningNotes: [String: String]

    // Sleep tracking per day
    // In React: sleepNotes["Monday"] = { wakeUp: "6:30", bedTime: "8:00" }
    var sleepNotes: [String: SleepData]

    // Generated reports (markdown text)
    // In React: report (parent-friendly) and care_report (clinical)
    var report: String?
    var careReport: String?

    var updatedAt: Date

    init(
        weekId: String,
        entries: [String: String] = [:],
        parsedEntries: [String: ParsedDayData] = [:],
        morningNotes: [String: String] = [:],
        eveningNotes: [String: String] = [:],
        sleepNotes: [String: SleepData] = [:],
        report: String? = nil,
        careReport: String? = nil
    ) {
        self.weekId = weekId
        self.entries = entries
        self.parsedEntries = parsedEntries
        self.morningNotes = morningNotes
        self.eveningNotes = eveningNotes
        self.sleepNotes = sleepNotes
        self.report = report
        self.careReport = careReport
        self.updatedAt = Date()
    }
}

// MARK: - ParsedDayData
// ─────────────────────────────────────────────────────────────────────
// Maps to your React `parsedEntries[day]` shape.
// In React this was a plain JS object. In Swift, we make it a Codable struct.
//
// Think of Codable as implementing both Serializable AND a JSON mapper
// (like Jackson's @JsonProperty in Spring Boot) — Swift handles both
// directions (encode + decode) from a single protocol.
// ─────────────────────────────────────────────────────────────────────

struct ParsedDayData: Codable, Hashable {
    var eating: CategoryData
    var naps: CategoryData
    var potty: CategoryData
    var activities: [String]
    var teacherNotes: String
    var mood: String
    var moodRating: StatusRating

    init(
        eating: CategoryData = CategoryData(),
        naps: CategoryData = CategoryData(),
        potty: CategoryData = CategoryData(),
        activities: [String] = [],
        teacherNotes: String = "",
        mood: String = "",
        moodRating: StatusRating = .none
    ) {
        self.eating = eating
        self.naps = naps
        self.potty = potty
        self.activities = activities
        self.teacherNotes = teacherNotes
        self.mood = mood
        self.moodRating = moodRating
    }
}

// MARK: - CategoryData
// ─────────────────────────────────────────────────────────────────────
// Each category (eating, naps, potty) has a summary, details, and rating.
// In React: { summary: "Ate well", details: ["Finished lunch"], rating: "green" }
// ─────────────────────────────────────────────────────────────────────

struct CategoryData: Codable, Hashable {
    var summary: String
    var details: [String]
    var rating: StatusRating

    init(summary: String = "", details: [String] = [], rating: StatusRating = .none) {
        self.summary = summary
        self.details = details
        self.rating = rating
    }
}

// MARK: - StatusRating
// ─────────────────────────────────────────────────────────────────────
// In React you used string literals: "green" | "yellow" | "red" | "none"
// In Swift, we use an enum — like a Java enum but WAY more powerful.
//
// Swift enums can:
//   - Conform to protocols (Codable makes it JSON-serializable)
//   - Have computed properties (like the color mapping below)
//   - Have associated values (not used here, but think sealed classes in Kotlin)
//
// The raw value (String) means it serializes to/from "green", "yellow", etc.
// — exactly matching what Claude returns in its JSON responses.
// ─────────────────────────────────────────────────────────────────────

enum StatusRating: String, Codable, Hashable, CaseIterable {
    case green
    case yellow
    case red
    case none

    /// Human-readable label for the UI
    var label: String {
        switch self {
        case .green: return "Normal"
        case .yellow: return "Off routine"
        case .red: return "Flagged"
        case .none: return "—"
        }
    }
}

// MARK: - SleepData
// ─────────────────────────────────────────────────────────────────────
// In React: sleepNotes[day] = { wakeUp: "6:30", bedTime: "8:00" }
// Simple struct — Codable so SwiftData can persist it in the dictionary.
// ─────────────────────────────────────────────────────────────────────

struct SleepData: Codable, Hashable {
    var wakeUp: String
    var bedTime: String

    init(wakeUp: String = "", bedTime: String = "") {
        self.wakeUp = wakeUp
        self.bedTime = bedTime
    }
}

// MARK: - Convenience Extensions

extension WeekEntry {
    /// Check if a specific day has any data (parsed entry, notes, or sleep)
    /// In React this was checked inline: entries[day] || eveningNotes[day] || sleepNotes[day]
    func hasData(for day: String) -> Bool {
        return parsedEntries[day] != nil
            || !(eveningNotes[day]?.isEmpty ?? true)
            || sleepNotes[day] != nil
    }

    /// Count of days that have data — drives the progress bar on the dashboard
    var filledDayCount: Int {
        let days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        return days.filter { hasData(for: $0) }.count
    }

    /// Get the aggregate week rating for a category
    /// Logic from React's weekCatRating(): any red → red, any yellow → yellow, else green
    func weekRating(for keyPath: KeyPath<ParsedDayData, CategoryData>) -> StatusRating {
        let ratings = parsedEntries.values.map { $0[keyPath: keyPath].rating }
        if ratings.contains(.red) { return .red }
        if ratings.contains(.yellow) { return .yellow }
        if ratings.contains(.green) { return .green }
        return .none
    }

    /// Week rating for mood specifically (it's a standalone rating, not a CategoryData)
    var weekMoodRating: StatusRating {
        let ratings = parsedEntries.values.map { $0.moodRating }
        if ratings.contains(.red) { return .red }
        if ratings.contains(.yellow) { return .yellow }
        if ratings.contains(.green) { return .green }
        return .none
    }
}
