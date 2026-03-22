//
//  DateHelpers.swift
//  CareThread
//
//  Created by Gian Ramirez on 3/18/26.
//

import Foundation

enum DateHelpers {

    static let dayNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
    static let weekdayNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
    static let shortDayNames = ["M", "T", "W", "T", "F", "S", "S"]

    // MARK: - Week Calculations

    static func mondayOfWeek(containing date: Date) -> Date {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        let daysFromMonday = (weekday + 5) % 7
        return calendar.date(byAdding: .day, value: -daysFromMonday, to: calendar.startOfDay(for: date))!
    }

    static func weekKey(for monday: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: monday)
    }

    static func formatWeekLabel(_ monday: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: monday)
    }

    static func dateForDay(monday: Date, dayIndex: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: dayIndex, to: monday)!
    }

    static func fmtShort(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }

    static func dayTabLabel(dayIndex: Int, monday: Date) -> String {
        let date = dateForDay(monday: monday, dayIndex: dayIndex)
        return "\(shortDayNames[dayIndex]) \(fmtShort(date))"
    }

    // MARK: - Week Navigation

    static func offsetWeek(_ monday: Date, by weeks: Int) -> Date {
        Calendar.current.date(byAdding: .weekOfYear, value: weeks, to: monday)!
    }

    static func isFutureWeek(_ monday: Date) -> Bool {
        let currentMonday = mondayOfWeek(containing: Date())
        return monday > currentMonday
    }

    static func isWeekend(_ dayIndex: Int) -> Bool {
        dayIndex >= 5
    }

    // MARK: - Calendar Dropdown

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
                if weekday == 2 {
                    mondays.append(keyFormatter.string(from: date))
                }
            }
        }
        return mondays
    }
}
