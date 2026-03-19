import SwiftUI
import SwiftData

// MARK: - DashboardView
// ─────────────────────────────────────────────────────────────────────
// Maps to your React Dashboard tab — the main week overview screen.
//
// This is the most complex view. In React, it was part of App.jsx's
// render with view === "dashboard". Here we extract it as its own View.
//
// KEY SWIFTUI CONCEPTS:
//
// @Query: SwiftData's version of a database query that auto-updates.
//   Think of it like a React useEffect that watches a database table
//   and re-renders whenever data changes. Or in Spring Boot terms,
//   it's like a @Repository method that's "live" — it automatically
//   re-fetches when the underlying data changes.
//
// @Environment: Access to shared context provided by parent views.
//   Like React's useContext() — the ModelContext is injected by SwiftData
//   at the app level and available everywhere.
//
// LazyVGrid: A grid layout that only renders visible items.
//   Like React's CSS Grid but with lazy loading built in.
//   The "lazy" means items offscreen aren't rendered — important for
//   performance on scrollable lists.
// ─────────────────────────────────────────────────────────────────────

struct DashboardView: View {
    @Binding var currentMonday: Date
    @Binding var selectedTab: AppTab
    @Binding var activeDay: Int

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var apiService: ClaudeAPIService

    // Fetch the current week's data
    // This will be filtered in the computed property below
    @Query private var allWeeks: [WeekEntry]
    @Query private var allSettings: [AppSettings]

    @State private var toastMessage: String?
    @State private var toastIsError = false

    // MARK: - Computed Properties

    /// Get the WeekEntry for the current Monday
    private var currentWeek: WeekEntry? {
        let key = DateHelpers.weekKey(for: currentMonday)
        return allWeeks.first { $0.weekId == key }
    }

    /// Get settings (singleton)
    private var settings: AppSettings? {
        allSettings.first
    }

    // Grid layout — 2 columns for the category cards
    // In React you used CSS grid-template-columns: repeat(2, 1fr)
    private let categoryGrid = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Progress bar
                progressBar

                // Category cards grid (Eating, Naps, Potty, Mood)
                categoryCardsSection

                // Daily breakdown list
                dailyBreakdownSection

                // Generate report button
                if let week = currentWeek, week.filledDayCount > 0 {
                    generateReportButton(week: week)
                }
            }
            .padding()
        }
        .toast(message: $toastMessage, isError: toastIsError)
    }

    // MARK: - Progress Bar

    /// Shows "X/7 days" — maps to your React progress bar in the header.
    private var progressBar: some View {
        let filled = currentWeek?.filledDayCount ?? 0
        return VStack(spacing: 4) {
            HStack {
                Text("\(filled)/7 days logged")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            // SwiftUI's ProgressView with a value — native progress bar!
            // In React you built this with a div + width percentage.
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppTheme.accent)
                        .frame(width: geo.size.width * CGFloat(filled) / 7.0, height: 6)
                        .animation(.easeInOut, value: filled)
                }
            }
            .frame(height: 6)
        }
    }

    // MARK: - Category Cards

    /// The 2x2 grid of category cards (Eating, Naps, Potty, Mood).
    /// Each card shows daily status dots for the week.
    private var categoryCardsSection: some View {
        LazyVGrid(columns: categoryGrid, spacing: 12) {
            ForEach(Categories.all) { category in
                CategoryCardView(
                    category: category,
                    weekEntry: currentWeek,
                    monday: currentMonday
                )
            }
        }
    }

    // MARK: - Daily Breakdown

    /// The day-by-day list below the cards.
    /// In React: the daily breakdown <ul> with clickable rows.
    private var dailyBreakdownSection: some View {
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
                        // Day name + date
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
                                    Text("🏠")
                                        .font(.caption)
                                }
                            }

                            // Show routine schedule if set
                            if let label = settings?.scheduleLabel(for: dayName),
                               !label.isEmpty {
                                Text(label)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Text(DateHelpers.formatShort(
                                DateHelpers.date(for: dayIndex, in: currentMonday)
                            ))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        }

                        Spacer()

                        // Status dots for this day (one per category)
                        if let parsed = currentWeek?.parsedEntries[dayName] {
                            HStack(spacing: 6) {
                                StatusDot(rating: parsed.eating.rating, size: 8)
                                StatusDot(rating: parsed.naps.rating, size: 8)
                                StatusDot(rating: parsed.potty.rating, size: 8)
                                StatusDot(rating: parsed.moodRating, size: 8)
                            }
                        }

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(12)
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Generate Report Button

    private func generateReportButton(week: WeekEntry) -> some View {
        Button {
            Task {
                await generateWeeklyReport(for: week)
            }
        } label: {
            Label("Generate Weekly Report", systemImage: "doc.text.magnifyingglass")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .disabled(apiService.isLoading)
    }

    // MARK: - Report Generation

    /// Generates both parent and care team reports.
    /// Maps to your React generateReport() function.
    private func generateWeeklyReport(for week: WeekEntry) async {
        // Build the daily data string (same format as React)
        var dailyData = ""
        for dayIndex in 0..<7 {
            let dayName = DateHelpers.dayNames[dayIndex]
            guard week.hasData(for: dayName) else { continue }

            dailyData += "### \(dayName)\n"

            if let parsed = week.parsedEntries[dayName] {
                dailyData += "- Eating: \(parsed.eating.summary) (\(parsed.eating.rating.rawValue))\n"
                dailyData += "- Naps: \(parsed.naps.summary) (\(parsed.naps.rating.rawValue))\n"
                dailyData += "- Potty: \(parsed.potty.summary) (\(parsed.potty.rating.rawValue))\n"
                dailyData += "- Mood: \(parsed.mood) (\(parsed.moodRating.rawValue))\n"
                if !parsed.activities.isEmpty {
                    dailyData += "- Activities: \(parsed.activities.joined(separator: ", "))\n"
                }
                if !parsed.teacherNotes.isEmpty {
                    dailyData += "- Teacher Notes: \(parsed.teacherNotes)\n"
                }
            }

            if let morningNote = week.morningNotes[dayName], !morningNote.isEmpty {
                dailyData += "- Morning Note: \(morningNote)\n"
            }
            if let eveningNote = week.eveningNotes[dayName], !eveningNote.isEmpty {
                dailyData += "- Evening Note: \(eveningNote)\n"
            }
            if let sleep = week.sleepNotes[dayName] {
                if !sleep.wakeUp.isEmpty { dailyData += "- Wake Up: \(sleep.wakeUp)\n" }
                if !sleep.bedTime.isEmpty { dailyData += "- Bed Time: \(sleep.bedTime)\n" }
            }
            dailyData += "\n"
        }

        do {
            let reports = try await apiService.generateWeeklyReports(
                weekData: dailyData,
                routineContext: settings?.routineContext() ?? "",
                therapyContext: settings?.therapySchedule ?? ""
            )

            // Save reports to the week entry
            week.report = reports.parentReport
            week.careReport = reports.careReport
            week.updatedAt = Date()

            toastIsError = false
            toastMessage = "Reports generated!"
            selectedTab = .report
        } catch {
            toastIsError = true
            toastMessage = "Couldn't generate reports — try again."
            print("Report generation error: \(error)")
        }
    }
}

// MARK: - CategoryCardView
// ─────────────────────────────────────────────────────────────────────
// Each card in the 2x2 grid — shows the category icon, label,
// week rating, and daily status dots.
//
// In React this was rendered inline in the dashboard JSX.
// ─────────────────────────────────────────────────────────────────────

struct CategoryCardView: View {
    let category: TrackingCategory
    let weekEntry: WeekEntry?
    let monday: Date

    /// Get the week-level rating for this category
    private var weekRating: StatusRating {
        guard let week = weekEntry else { return .none }
        switch category.key {
        case "eating": return week.weekRating(for: \.eating)
        case "naps": return week.weekRating(for: \.naps)
        case "potty": return week.weekRating(for: \.potty)
        case "mood": return week.weekMoodRating
        default: return .none
        }
    }

    /// Get the daily rating for a specific day in this category
    private func dayRating(for dayName: String) -> StatusRating {
        guard let parsed = weekEntry?.parsedEntries[dayName] else { return .none }
        switch category.key {
        case "eating": return parsed.eating.rating
        case "naps": return parsed.naps.rating
        case "potty": return parsed.potty.rating
        case "mood": return parsed.moodRating
        default: return .none
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header: icon + label + week rating
            HStack {
                Text(category.icon)
                    .font(.title3)
                Text(category.label)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                StatusLabel(rating: weekRating)
            }

            // Daily dots row (M T W T F S S)
            HStack(spacing: 4) {
                ForEach(0..<7, id: \.self) { dayIndex in
                    VStack(spacing: 2) {
                        Text(String(DateHelpers.dayNames[dayIndex].prefix(1)))
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                        StatusDot(
                            rating: dayRating(for: DateHelpers.dayNames[dayIndex]),
                            size: 8
                        )
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .cardStyle()
    }
}
