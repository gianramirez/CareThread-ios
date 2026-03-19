import Foundation
import SwiftData

// MARK: - AppSettings
// ─────────────────────────────────────────────────────────────────────
// Maps to your React `settings` table in Supabase.
// In React: { routine: {Monday: "School"}, appointments: {...}, therapy_schedule, pin_code }
//
// SwiftData @Model is a singleton pattern here — we only ever have ONE
// settings record (like your id="global" row in Supabase).
//
// Java equivalent: Think of this as a @Configuration bean that persists
// its values to a database instead of application.yml.
// ─────────────────────────────────────────────────────────────────────

@Model
final class AppSettings {
    @Attribute(.unique)
    var id: String  // Always "global" — singleton pattern

    // Mon–Fri location: "School", "Home", "Daycare", or "" (none)
    // In React: routine = { Monday: "School", Tuesday: "Daycare", ... }
    var routine: [String: String]

    // Daily appointment notes
    // In React: appointments = { Monday: "OT 10am", ... }
    var appointments: [String: String]

    // Free-text therapy schedule
    var therapySchedule: String

    // PIN lock code (4-8 digits)
    // Stored locally — in production you'd use Keychain for sensitive data
    var pinCode: String

    var updatedAt: Date

    init(
        routine: [String: String] = [:],
        appointments: [String: String] = [:],
        therapySchedule: String = "",
        pinCode: String = ""
    ) {
        self.id = "global"
        self.routine = routine
        self.appointments = appointments
        self.therapySchedule = therapySchedule
        self.pinCode = pinCode
        self.updatedAt = Date()
    }
}

// MARK: - DayLocation
// ─────────────────────────────────────────────────────────────────────
// Type-safe enum for location options.
// In React these were string literals in a <select> dropdown.
// ─────────────────────────────────────────────────────────────────────

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

// MARK: - Convenience

extension AppSettings {
    /// Build the routine context string for Claude prompts
    /// Matches React's ROUTINE_CONTEXT construction
    func routineContext() -> String {
        let weekdays = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
        var lines: [String] = []

        for day in weekdays {
            let location = routine[day] ?? ""
            let appt = appointments[day] ?? ""
            var line = "\(day): \(location.isEmpty ? "Not set" : location)"
            if !appt.isEmpty {
                line += " — \(appt)"
            }
            lines.append(line)
        }

        return lines.joined(separator: "\n")
    }

    /// Format a single day's schedule label
    /// In React: schedLabel(day) → "School · OT 10am"
    func scheduleLabel(for day: String) -> String {
        let location = routine[day] ?? ""
        let appt = appointments[day] ?? ""
        var parts: [String] = []
        if !location.isEmpty { parts.append(location) }
        if !appt.isEmpty { parts.append(appt) }
        return parts.joined(separator: " · ")
    }
}
