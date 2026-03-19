//
//  AppSettings.swift
//  CareThread
//
//  Created by Gian Ramirez on 3/18/26.
//

import Foundation
import SwiftData

@Model
final class AppSettings {
    @Attribute(.unique)
    var settingsId: String  // Always "global"

    // Daily routine — maps to your React { Monday: "School", Tuesday: "Daycare", ... }
    var routine: [String: String]

    // Daily appointments — { Monday: "OT 10am", Wednesday: "Speech 2pm" }
    var appointments: [String: String]

    // Free-text therapy schedule
    var therapySchedule: String

    // PIN lock code (4-8 digits)
    var pinCode: String

    var updatedAt: Date

    init() {
        self.settingsId = "global"
        self.routine = [:]
        self.appointments = [:]
        self.therapySchedule = ""
        self.pinCode = ""
        self.updatedAt = Date()
    }
}

enum DayLocation: String, CaseIterable, Identifiable {
    case none = ""
    case school = "School"
    case home = "Home"
    case daycare = "Daycare"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: return "None"
        case .school: return "School"
        case .home: return "Home"
        case .daycare: return "Daycare"
        }
    }
}
