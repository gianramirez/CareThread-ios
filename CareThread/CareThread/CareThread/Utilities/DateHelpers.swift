import Foundation

// MARK: - DateHelpers
// ─────────────────────────────────────────────────────────────────────
// Translates all the date utility functions from your React app.
//
// In React, you used raw JS Date objects and manual math.
// In Swift, we use Calendar and DateFormatter — think of Calendar as
// Java's java.time.LocalDate utilities, and DateFormatter as
// java.time.format.DateTimeFormatter.
//
// Key Swift concept: `Calendar.current` is locale-aware and handles
// all the edge cases (DST, week boundaries) that you'd manually
// handle in JS.
// ─────────────────────────────────────────────────────────────────────

enum DateHelpers {
    // Using an enum with no cases as a namespace — like a Java utility class
    // with a private constructor. Can't be instantiated, just holds static methods.

    /// The 7 day names used as dictionary keys throughout the app
    static let dayNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

    /// Weekday-only names (Mon–Fri) for settings/routine
    static let weekdayNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]

    // MARK: - Week Calculations

    /// Get the Monday of the week containing the given date.
    /// React equivalent: getMondayOfWeek(date)
    ///
    /// In JS you did: d.setDate(d.getDate() - ((d.getDay() + 6) % 7))
    /// Swift's Calendar makes this much cleaner.
    static func mondayOfWeek(containing date: Date) -> Date {
        let cal = Calendar(identifier: .iso8601)  // ISO 8601 weeks start on Monday
        let components = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return cal.date(from: components)!
    }

    /// Generate the week key string ("YYYY-MM-DD") for a Monday date.
    /// React equivalent: weekKey(monday) — used as the database primary key.
    static func weekKey(for monday: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: monday)
    }

    /// Get the Date for a specific day index (0=Monday, 6=Sunday) in a week.
    /// React equivalent: dateForDay(monday, dayIndex)
    static func date(for dayIndex: Int, in mondayDate: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: dayIndex, to: mondayDate)!
    }

    // MARK: - Navigation

    /// Move forward or backward by one week.
    /// React equivalent: goWeek(dir) where dir is +1 or -1
    static func offsetWeek(_ monday: Date, by weeks: Int) -> Date {
        Calendar.current.date(byAdding: .weekOfYear, value: weeks, to: monday)!
    }

    /// Check if a date is in the future (prevents navigating to future weeks).
    static func isFutureWeek(_ monday: Date) -> Bool {
        let today = mondayOfWeek(containing: Date())
        return monday > today
    }

    // MARK: - Formatting

    /// Format as "Jan 15, 2026" — used in the week navigation header.
    /// React equivalent: formatWeekLabel(monday)
    static func formatWeekLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }

    /// Format as "1/15" — short date for day tabs.
    /// React equivalent: fmtShort(date)
    static func formatShort(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }

    /// Format day tab label: "Mon 1/15"
    static func dayTabLabel(dayIndex: Int, monday: Date) -> String {
        let d = date(for: dayIndex, in: monday)
        let short = dayNames[dayIndex].prefix(3)  // "Mon", "Tue", etc.
        return "\(short) \(formatShort(d))"
    }

    // MARK: - Month Helpers

    /// Get the last 6 months as (label, "YYYY-MM") tuples.
    /// React equivalent: getMonthOptions()
    static func monthOptions() -> [(label: String, value: String)] {
        let cal = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"

        let keyFormatter = DateFormatter()
        keyFormatter.dateFormat = "yyyy-MM"

        return (0..<6).map { offset in
            let month = cal.date(byAdding: .month, value: -offset, to: Date())!
            return (label: formatter.string(from: month), value: keyFormatter.string(from: month))
        }
    }

    /// Get all Mondays that fall within a given month ("YYYY-MM").
    /// React equivalent: getMondaysInMonth(yearMonth)
    /// Used to fetch weekly reports for monthly report generation.
    static func mondaysInMonth(_ yearMonth: String) -> [String] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        guard let startOfMonth = formatter.date(from: yearMonth) else { return [] }

        let cal = Calendar.current
        guard let range = cal.range(of: .day, in: .month, for: startOfMonth) else { return [] }

        let keyFormatter = DateFormatter()
        keyFormatter.dateFormat = "yyyy-MM-dd"

        var mondays: Set<String> = []
        for day in range {
            guard let date = cal.date(byAdding: .day, value: day - 1, to: startOfMonth) else { continue }
            let monday = mondayOfWeek(containing: date)
            mondays.insert(keyFormatter.string(from: monday))
        }

        return mondays.sorted()
    }

    /// Get the last 13 weeks as (label, monday Date) tuples for the calendar dropdown.
    /// React equivalent: getCalendarWeeks()
    static func calendarWeeks() -> [(label: String, monday: Date)] {
        let thisMonday = mondayOfWeek(containing: Date())
        return (0..<13).map { offset in
            let monday = offsetWeek(thisMonday, by: -offset)
            let label = "Week of \(formatWeekLabel(monday))"
            return (label: label, monday: monday)
        }
    }

    /// Check if a day index represents a weekend (5=Saturday, 6=Sunday)
    static func isWeekend(_ dayIndex: Int) -> Bool {
        dayIndex >= 5
    }
}
