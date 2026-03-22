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
    var weekId: String

    var entries: [String: String]
    var parsedEntries: [String: ParsedDayData]
    var morningNotes: [String: String]
    var eveningNotes: [String: String]
    var sleepNotes: [String: SleepData]
    var report: String?
    var careReport: String?
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

    func hasData(for day: String) -> Bool {
        parsedEntries[day] != nil
            || !(morningNotes[day]?.isEmpty ?? true)
            || !(eveningNotes[day]?.isEmpty ?? true)
            || sleepNotes[day] != nil
    }

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
    var wakeUp: String
    var bedTime: String
}
