//
//  WeekEntry.swift
//  CareThread
//
//  Created by Gian Ramirez on 3/18/26.
//

import Foundation
import SwiftData

@Model
final class WeekEntry {
    @Attribute(.unique)
    var weekId: String  // Format: "YYYY-MM-DD" (Monday date) — like your React weekKey

    // Raw entry text per day — { "Monday": "pasted text...", "Tuesday": "[Screenshot]" }
    var entries: [String: String]

    // Claude-parsed data per day — the structured eating/naps/potty/mood data
    var parsedEntries: [String: ParsedDayData]

    // Parent notes
    var morningNotes: [String: String]
    var eveningNotes: [String: String]
    var sleepNotes: [String: SleepData]

    // Generated reports
    var report: String?       // Parent-friendly weekly report
    var careReport: String?   // Care team clinical report

    var updatedAt: Date

    init(weekId: String) {
        self.weekId = weekId
        self.entries = [:]
        self.parsedEntries = [:]
        self.morningNotes = [:]
        self.eveningNotes = [:]
        self.sleepNotes = [:]
        self.report = nil
        self.careReport = nil
        self.updatedAt = Date()
    }

    /// Check if a day has any data (parsed entry, notes, or sleep)
    func hasData(for day: String) -> Bool {
        parsedEntries[day] != nil
            || !(eveningNotes[day]?.isEmpty ?? true)
            || sleepNotes[day] != nil
    }

    /// Get the number of days that have data
    var filledDayCount: Int {
        DateHelpers.dayNames.filter { hasData(for: $0) }.count
    }
}

struct ParsedDayData: Codable {
    var eating: CategoryData
    var naps: CategoryData
    var potty: CategoryData
    var activities: [String]
    var teacherNotes: String
    var mood: String
    var moodRating: StatusRating

    enum CodingKeys: String, CodingKey {
        case eating, naps, potty, activities
        case teacherNotes = "teacherNotes"
        case mood
        case moodRating = "moodRating"
    }
}


struct CategoryData: Codable {
    var summary: String
    var details: [String]
    var rating: StatusRating
}

enum StatusRating: String, Codable, CaseIterable {
    case green
    case yellow
    case red
    case none

    var displayName: String {
        switch self {
        case .green: return "Normal"
        case .yellow: return "Off routine"
        case .red: return "Flagged"
        case .none: return "No data"
        }
    }
}

struct SleepData: Codable {
    var wakeUp: String   // e.g., "6:30"
    var bedTime: String  // e.g., "8:00"
}
