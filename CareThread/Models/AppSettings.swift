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
    var settingsId: String

    var routine: [String: String]
    var appointments: [String: String]
    var therapySchedule: String
    var isLockEnabled: Bool
    var updatedAt: Date

    init() {
        self.settingsId = "global"
        self.routine = [:]
        self.appointments = [:]
        self.therapySchedule = ""
        self.isLockEnabled = false
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
