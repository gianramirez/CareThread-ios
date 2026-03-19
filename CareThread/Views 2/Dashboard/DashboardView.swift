//
//  DashboardView.swift
//  CareThread
//
//  Created by Gian Ramirez on 3/18/26.
//

import SwiftUI
import SwiftData

// MARK: - DashboardView
// Maps to your React Dashboard tab — the main week overview with
// category cards, status dot grids, and daily breakdown.

struct DashboardView: View {
    @Binding var currentMonday: Date
    @Binding var selectedTab: AppTab
    @Binding var activeDay: Int

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var apiService: ClaudeAPIService

    @Query private var allWeeks: [WeekEntry]
    @Query private var allSettings: [AppSettings]

    @State private var toastMessage: String?
    @State private var toastIsError = false

    private var weekKey: String {
        DateHelpers.weekKey(for: currentMonday)
    }

    private var currentWeek: WeekEntry? {
        allWeeks.first { $0.weekId == weekKey }
    }

    private var settings: AppSettings? {
        allSettings.first
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Progress bar
                progressSection

                // Category cards grid (2x2)
                categoryCardsGrid

                // Daily breakdown list
                dailyBreakdownList

                // Generate report button
                if (currentWeek?.filledDayCount ?? 0) > 0 {
                    generateReportButton
                }
            }
            .padding()
        }
        .toast(message: $toastMessage, isError: toastIsError)
    }

    // MARK: - Progress Bar

    private var progressSection: some View {
        VStack(spacing: 4) {
            HStack {
                Text("\(currentWeek?.filledDayCount ?? 0)/7 days")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppTheme.accent)
                        .frame(
                            width: geo.size.width * CGFloat(currentWeek?.filledDayCount ?? 0) / 7.0,
                            height: 6
                        )
                        .animation(.easeInOut, value: currentWeek?.filledDayCount)
                }
            }
            .frame(height: 6)
        }
    }

    // MARK: - Category Cards

    private var categoryCardsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12),
        ], spacing: 12) {
            ForEach(Categories.all) { category in
                categoryCard(category)
            }
        }
    }

    private func categoryCard(_ category: TrackingCategory) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Text(category.icon)
                Text(category.label)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                StatusLabel(rating: weekCategoryRating(category.id))
            }

            // Daily status dots (M T W T F S S)
            HStack(spacing: 4) {
                ForEach(0..<7, id: \.self) { dayIndex in
                    let dayName = DateHelpers.dayNames[dayIndex]
                    let rating = dayRating(for: category.id, day: dayName)

                    VStack(spacing: 2) {
                        Text(DateHelpers.shortDayNames[dayIndex])
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                        StatusDot(rating: rating, size: 8)
                    }
                }
            }
        }
        .cardStyle()
    }

    /// Get the rating for a specific category on a specific day
    private func dayRating(for categoryId: String, day: String) -> StatusRating {
        guard let parsed = currentWeek?.parsedEntries[day] else { return .none }
        let category = Categories.all.first { $0.id == categoryId }
        return category?.data(from: parsed).rating ?? .none
    }

    /// Aggregate daily ratings into a week rating
    /// Maps to your React weekCatRating(key)
    private func weekCategoryRating(_ categoryId: String) -> StatusRating {
        let ratings = DateHelpers.dayNames.map { dayRating(for: categoryId, day: $0) }
            .filter { $0 != .none }

        if ratings.isEmpty { return .none }
        if ratings.contains(.red) { return .red }
        if ratings.contains(.yellow) { return .yellow }
        return .green
    }

    // MARK: - Daily Breakdown

    private var dailyBreakdownList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Daily Breakdown")
                .font(.headline)

            ForEach(0..<7, id: \.self) { dayIndex in
                let dayName = DateHelpers.dayNames[dayIndex]
                let hasData = currentWeek?.hasData(for: dayName) ?? false
                let hasEveningNote = !(currentWeek?.eveningNotes[dayName]?.isEmpty ?? true)

                Button {
                    activeDay = dayIndex
                    selectedTab = .logDay
                } label: {
                    HStack(spacing: 12) {
                        // Day label
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(dayName)
                                    .font(.subheadline.weight(.medium))
                                if hasData {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.green)
                                }
                                if hasEveningNote {
                                    Image(systemName: "house.fill")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            // Routine + appointments
                            if let label = scheduleLabel(for: dayName) {
                                Text(label)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }

                        Spacer()

                        // Status dots for each category
                        if hasData {
                            HStack(spacing: 6) {
                                ForEach(Categories.all) { cat in
                                    StatusDot(rating: dayRating(for: cat.id, day: dayName), size: 8)
                                }
                            }
                        }

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                }
                .buttonStyle(.plain)
            }
        }
        .cardStyle()
    }

    /// Get schedule label for a day — maps to your React schedLabel()
    private func scheduleLabel(for day: String) -> String? {
        var parts: [String] = []
        if let location = settings?.routine[day], !location.isEmpty {
            parts.append(location)
        }
        if let appt = settings?.appointments[day], !appt.isEmpty {
            parts.append(appt)
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    // MARK: - Generate Report Button

    private var generateReportButton: some View {
        Button {
            Task { await generateReport() }
        } label: {
            Label(
                apiService.isLoading ? "Generating..." : "Generate Weekly Report",
                systemImage: "doc.text.magnifyingglass"
            )
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .disabled(apiService.isLoading)
    }

    /// Maps to your React generateReport() function
    private func generateReport() async {
        guard let week = currentWeek else { return }

        // Build the daily data string (same format as your React app)
        var weekData = ""
        for dayIndex in 0..<7 {
            let dayName = DateHelpers.dayNames[dayIndex]
            guard week.hasData(for: dayName) else { continue }

            weekData += "### \(dayName)\n"

            if let parsed = week.parsedEntries[dayName] {
                weekData += "Eating: \(parsed.eating.summary) [\(parsed.eating.rating.rawValue)]\n"
                weekData += "Naps: \(parsed.naps.summary) [\(parsed.naps.rating.rawValue)]\n"
                weekData += "Potty: \(parsed.potty.summary) [\(parsed.potty.rating.rawValue)]\n"
                weekData += "Mood: \(parsed.mood) [\(parsed.moodRating.rawValue)]\n"
                if !parsed.activities.isEmpty {
                    weekData += "Activities: \(parsed.activities.joined(separator: ", "))\n"
                }
                if !parsed.teacherNotes.isEmpty {
                    weekData += "Teacher Notes: \(parsed.teacherNotes)\n"
                }
            }

            if let morningNote = week.morningNotes[dayName], !morningNote.isEmpty {
                weekData += "Morning Note: \(morningNote)\n"
            }
            if let eveningNote = week.eveningNotes[dayName], !eveningNote.isEmpty {
                weekData += "Evening Note: \(eveningNote)\n"
            }
            if let sleep = week.sleepNotes[dayName] {
                weekData += "Sleep: Wake \(sleep.wakeUp), Bed \(sleep.bedTime)\n"
            }
            weekData += "\n"
        }

        // Build context strings
        var routineContext = ""
        if let s = settings {
            for day in DateHelpers.weekdayNames {
                let location = s.routine[day] ?? ""
                let appt = s.appointments[day] ?? ""
                if !location.isEmpty || !appt.isEmpty {
                    routineContext += "\(day): \(location) \(appt)\n"
                }
            }
        }

        do {
            let reports = try await apiService.generateWeeklyReports(
                weekData: weekData,
                routineContext: routineContext,
                therapyContext: settings?.therapySchedule ?? ""
            )

            week.report = reports.parentReport
            week.careReport = reports.careReport
            week.updatedAt = Date()

            toastIsError = false
            toastMessage = "Reports generated!"
            selectedTab = .report
        } catch {
            toastIsError = true
            toastMessage = "Couldn't generate reports."
            print("Report error: \(error)")
        }
    }
}
