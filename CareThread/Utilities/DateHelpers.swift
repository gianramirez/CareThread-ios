//
//  DateHelpers.swift
//  CareThread
//
//  Created by Gian Ramirez on 3/18/26.
//

import Foundation

// MARK: - DateHelpers
// ─────────────────────────────────────────────────────────────────────
// Translates all your React date utility functions to Swift.
//
// In React: getMondayOfWeek(), formatWeekLabel(), weekKey(), etc.
// These were standalone functions in App.jsx.
//
// In Swift: We group them as static methods on a DateHelpers enum.
// Using an enum with no cases (instead of a struct or class) is a Swift
// pattern for "namespaces" — it prevents accidental instantiation.
// In Java terms: like a utility class with a private constructor.
//
// KEY CONCEPT — Calendar vs Date:
// Swift separates "a point in time" (Date) from "how we interpret it"
// (Calendar). This is like Java's Instant vs LocalDate/ZonedDateTime.
//
// Date ≈ Java's Instant (absolute timestamp)
// Calendar ≈ Java's ZoneId + locale rules
// DateComponents ≈ Java's LocalDate/LocalTime fields
// DateFormatter ≈ Java's DateTimeFormatter
// ─────────────────────────────────────────────────────────────────────

enum DateHelpers {
    // MARK: - Constants

    /// Full day names — matches your React DAYS array
    static let dayNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

    /// Weekday-only names (Mon-Fri) — used in settings
    static let weekdayNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]

    /// Short day labels for the day selector tabs
    static let shortDayNames = ["M", "T", "W", "T", "F", "S", "S"]

    // MARK: - Week Calculations

    /// Get the Monday of the week containing the given date.
    /// Maps to your React: getMondayOfWeek(date)
    ///
    /// Calendar.current automatically uses the device's locale and timezone.
    /// In Java: this would be `date.with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY))`
    static func mondayOfWeek(containing date: Date) -> Date {
        let calendar = Calendar.current
        // Get the weekday (1=Sunday, 2=Monday, ..., 7=Saturday in Gregorian)
        let weekday = calendar.component(.weekday, from: date)
        // Calculate days to subtract to get to Monday
        let daysFromMonday = (weekday + 5) % 7  // Converts to 0=Mon, 1=Tue, ..., 6=Sun
        return calendar.date(byAdding: .day, value: -daysFromMonday, to: calendar.startOfDay(for: date))!
    }

    /// Generate the week key string — matches your React weekKey(monday)
    /// Format: "YYYY-MM-DD"
    static func weekKey(for monday: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: monday)
    }

    /// Format the week label — matches your React formatWeekLabel(monday)
    /// Example: "Jan 15, 2026"
    static func formatWeekLabel(_ monday: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: monday)
    }

    /// Get the date for a specific day index within a week.
    /// Maps to your React: dateForDay(monday, dayIndex)
    /// dayIndex: 0=Monday, 1=Tuesday, ..., 6=Sunday
    static func dateForDay(monday: Date, dayIndex: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: dayIndex, to: monday)!
    }

    /// Short date format — matches your React fmtShort(date)
    /// Example: "1/15"
    static func fmtShort(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }

    /// Tab label for a day (short name + date)
    /// Example: "M 1/15"
    static func dayTabLabel(dayIndex: Int, monday: Date) -> String {
        let date = dateForDay(monday: monday, dayIndex: dayIndex)
        return "\(shortDayNames[dayIndex]) \(fmtShort(date))"
    }

    // MARK: - Week Navigation

    /// Offset the current Monday by a number of weeks.
    /// Maps to your React: goWeek(dir) where dir is +1 or -1
    static func offsetWeek(_ monday: Date, by weeks: Int) -> Date {
        Calendar.current.date(byAdding: .weekOfYear, value: weeks, to: monday)!
    }

    /// Check if a week is in the future (prevent navigating forward)
    static func isFutureWeek(_ monday: Date) -> Bool {
        let currentMonday = mondayOfWeek(containing: Date())
        return monday > currentMonday
    }

    /// Check if a day index is a weekend day
    static func isWeekend(_ dayIndex: Int) -> Bool {
        dayIndex >= 5  // 5=Saturday, 6=Sunday
    }

    // MARK: - Calendar Dropdown

    /// Get the last 13 weeks for the calendar dropdown.
    /// Maps to your React: getCalendarWeeks()
    static func calendarWeeks() -> [(monday: Date, label: String)] {
        let currentMonday = mondayOfWeek(containing: Date())
        return (0..<13).map { weeksBack in
            let monday = offsetWeek(currentMonday, by: -weeksBack)
            let endOfWeek = dateForDay(monday: monday, dayIndex: 6)
            let label = "\(formatWeekLabel(monday)) – \(fmtShort(endOfWeek))"
            return (monday: monday, label: label)
        }
    }

    // MARK: - Month Calculations

    /// Get month options (last 6 months) for the monthly report picker.
    /// Maps to your React: getMonthOptions()
    static func monthOptions() -> [(label: String, value: String)] {
        let calendar = Calendar.current
        let now = Date()
        let formatter = DateFormatter()

        return (0..<6).map { monthsBack in
            let date = calendar.date(byAdding: .month, value: -monthsBack, to: now)!
            formatter.dateFormat = "yyyy-MM"
            let value = formatter.string(from: date)
            formatter.dateFormat = "MMMM yyyy"
            let label = formatter.string(from: date)
            return (label: label, value: value)
        }
    }

    /// Get all Monday dates that fall within a given month.
    /// Maps to your React: getMondaysInMonth(yearMonth)
    /// Input: "2026-03" → returns ["2026-03-02", "2026-03-09", ...]
    static func mondaysInMonth(_ yearMonth: String) -> [String] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        guard let startOfMonth = formatter.date(from: yearMonth) else { return [] }

        let calendar = Calendar.current
        guard let range = calendar.range(of: .day, in: .month, for: startOfMonth) else { return [] }

        let keyFormatter = DateFormatter()
        keyFormatter.dateFormat = "yyyy-MM-dd"

        var mondays: [String] = []
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) {
                let weekday = calendar.component(.weekday, from: date)
                if weekday == 2 {  // Monday
                    mondays.append(keyFormatter.string(from: date))
                }
            }
        }
        return mondays
    }
}
