//
//  SampleData.swift
//  CareThread
//
//  Sample data for SwiftUI previews and development testing.
//

import Foundation
import SwiftData

enum SampleData {

    /// A week with mixed states: fully logged days, morning-only day, screenshot day
    @MainActor
    static func sampleWeek() -> WeekEntry {
        let week = WeekEntry(weekId: DateHelpers.weekKey(for: DateHelpers.mondayOfWeek(containing: Date())))

        // MARK: - Monday — fully complete day
        week.entries["Monday"] = "Breakfast: oatmeal (all), milk (half). Lunch: chicken nuggets (all), rice (half), apple slices (none). Snack: goldfish crackers, water. Nap: 12:30-2:15. Diaper changes: wet x3, BM x1. Activities: circle time, painting, outdoor play, story time. Happy at drop-off, fussy before nap, cheerful after."
        week.parsedEntries["Monday"] = ParsedDayData(
            eating: CategoryData(
                summary: "Ate most of lunch, skipped fruit",
                details: ["Chicken nuggets - all", "Rice - half", "Apple slices - none", "Oatmeal - all", "Milk - half"],
                rating: .yellow
            ),
            naps: CategoryData(
                summary: "Solid nap, slept the full window",
                details: ["12:30-2:15 (1h45m)"],
                rating: .green
            ),
            potty: CategoryData(
                summary: "Normal day, 4 changes",
                details: ["Wet x3", "BM x1 (normal)"],
                rating: .green
            ),
            activities: ["Circle time", "Painting", "Outdoor play", "Story time"],
            teacherNotes: "Played well with Emma today. Shared toys without prompting!",
            mood: "Happy at drop-off but got fussy before nap. Recovered well after nap and was cheerful rest of the day.",
            moodRating: .green
        )
        week.morningNotes["Monday"] = "Woke up cranky, didn't want breakfast. Took a while to get dressed."
        week.eveningNotes["Monday"] = "Had a meltdown at bath time. Calmed down with books."
        week.sleepNotes["Monday"] = SleepData(wakeUp: "6:15", bedTime: "7:30")

        // MARK: - Tuesday — screenshot entry (fully logged)
        week.entries["Tuesday"] = "[Screenshot]"
        week.parsedEntries["Tuesday"] = ParsedDayData(
            eating: CategoryData(
                summary: "Great appetite today, ate everything",
                details: ["Scrambled eggs - all", "Toast - all", "Pasta with marinara - all", "Banana - all"],
                rating: .green
            ),
            naps: CategoryData(
                summary: "Shorter nap than usual",
                details: ["12:45-1:45 (1h)"],
                rating: .yellow
            ),
            potty: CategoryData(
                summary: "Normal, 3 changes",
                details: ["Wet x2", "BM x1 (normal)"],
                rating: .green
            ),
            activities: ["Music class", "Block building", "Outdoor play"],
            teacherNotes: "Really engaged during music class. Clapped along to all the songs.",
            mood: "Energetic all day. A little resistant at nap time but otherwise happy.",
            moodRating: .green
        )
        week.morningNotes["Tuesday"] = "Great morning! Ate all his oatmeal and was excited for school."
        week.sleepNotes["Tuesday"] = SleepData(wakeUp: "7:00", bedTime: "8:15")

        // MARK: - Wednesday — morning-only (no daycare data yet)
        week.morningNotes["Wednesday"] = "Slept in a bit, seemed well-rested. Had half a banana before leaving."
        week.sleepNotes["Wednesday"] = SleepData(wakeUp: "6:45", bedTime: "")

        // MARK: - Thursday — parsed data, no morning note
        week.entries["Thursday"] = "Breakfast: yogurt (all), berries (half). Lunch: grilled cheese (most), tomato soup (half). Snack: crackers. Nap: 12:15-2:00. Diaper: wet x4, BM x1. Activities: playground, art, sensory bin. Mood: calm and focused."
        week.parsedEntries["Thursday"] = ParsedDayData(
            eating: CategoryData(
                summary: "Solid eating day, good variety",
                details: ["Yogurt - all", "Berries - half", "Grilled cheese - most", "Tomato soup - half"],
                rating: .green
            ),
            naps: CategoryData(
                summary: "Good nap, full duration",
                details: ["12:15-2:00 (1h45m)"],
                rating: .green
            ),
            potty: CategoryData(
                summary: "Normal day, 5 changes",
                details: ["Wet x4", "BM x1 (normal)"],
                rating: .green
            ),
            activities: ["Playground", "Art project", "Sensory bin"],
            teacherNotes: "Very focused during art today. Made a great finger painting!",
            mood: "Calm and focused throughout the day. No fussiness at transitions.",
            moodRating: .green
        )
        week.sleepNotes["Thursday"] = SleepData(wakeUp: "6:30", bedTime: "7:45")
        week.eveningNotes["Thursday"] = "Played outside after dinner, went to bed easily."

        // MARK: - Friday, Saturday, Sunday — no data

        return week
    }

    /// Seed the database with sample data if empty (DEBUG builds only).
    /// Safe to call on every launch — skips if any WeekEntry already exists.
    @MainActor
    static func seedIfEmpty(context: ModelContext) {
        let descriptor = FetchDescriptor<WeekEntry>()
        let count = (try? context.fetchCount(descriptor)) ?? 0
        guard count == 0 else { return }
        context.insert(sampleWeek())
    }

    /// A preview-ready model container with sample data pre-inserted
    @MainActor
    static var previewContainer: ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: WeekEntry.self, AppSettings.self, MonthlyReport.self,
            configurations: config
        )
        container.mainContext.insert(sampleWeek())
        return container
    }
}
