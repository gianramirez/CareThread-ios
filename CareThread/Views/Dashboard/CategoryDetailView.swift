//
//  CategoryDetailView.swift
//  CareThread
//

import SwiftUI
import SwiftData

struct CategoryDetailView: View {
    let categoryId: String
    let categoryLabel: String
    let systemIcon: String
    @Binding var currentMonday: Date

    @Environment(\.modelContext) private var modelContext
    @Environment(ClaudeAPIService.self) var apiService

    @Query private var allWeeks: [WeekEntry]

    @State private var summaryText: String?
    @State private var isGenerating = false
    @State private var errorMessage: String?

    private var weekKey: String { DateHelpers.weekKey(for: currentMonday) }
    private var currentWeek: WeekEntry? { allWeeks.first { $0.weekId == weekKey } }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerSection
                aiSummarySection
                dailyBreakdownSection
            }
            .padding()
        }
        .navigationTitle(categoryLabel)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadCachedOrGenerate() }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 12) {
            Image(systemName: systemIcon)
                .font(.title2)
                .foregroundStyle(AppTheme.color(for: overallRating))
            VStack(alignment: .leading, spacing: 2) {
                Text("Week of \(DateHelpers.formatWeekLabel(currentMonday))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                StatusLabel(rating: overallRating)
            }
            Spacer()
            dayDots
        }
        .cardStyle()
    }

    private var dayDots: some View {
        HStack(spacing: 4) {
            ForEach(0..<7, id: \.self) { dayIndex in
                let dayName = DateHelpers.dayNames[dayIndex]
                VStack(spacing: 2) {
                    Text(DateHelpers.shortDayNames[dayIndex])
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                    StatusDot(rating: ratingForDay(dayName), size: 10)
                }
            }
        }
    }

    // MARK: - AI Summary

    private var aiSummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(AppTheme.accent)
                Text("AI Summary")
                    .font(.headline)
                Spacer()

                if summaryText != nil {
                    Button {
                        Task { await generateSummary(force: true) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if isGenerating {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Analyzing \(categoryLabel.lowercased()) data...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 20)
            } else if let summary = summaryText {
                Text(summary)
                    .font(.subheadline)
                    .lineSpacing(4)
            } else if let error = errorMessage {
                VStack(spacing: 8) {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                    Button("Try Again") {
                        Task { await generateSummary(force: true) }
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                }
            } else if !hasCategoryData {
                Text("No \(categoryLabel.lowercased()) data logged this week yet.")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
        }
        .cardStyle()
    }

    // MARK: - Daily Breakdown

    private var dailyBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Daily Breakdown")
                .font(.headline)

            ForEach(0..<7, id: \.self) { dayIndex in
                let dayName = DateHelpers.dayNames[dayIndex]
                dayRow(dayName: dayName, dayIndex: dayIndex)
            }
        }
        .cardStyle()
    }

    @ViewBuilder
    private func dayRow(dayName: String, dayIndex: Int) -> some View {
        let rating = ratingForDay(dayName)

        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(dayName)
                    .font(.subheadline.weight(.semibold))
                StatusDot(rating: rating, size: 8)
                Spacer()
                if rating != .none {
                    StatusLabel(rating: rating)
                }
            }

            if categoryId == "health" {
                healthDayContent(dayName: dayName)
            } else if let parsed = currentWeek?.parsedEntries[dayName] {
                parsedDayContent(parsed: parsed, dayName: dayName)
            } else {
                Text("No data")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 6)

        if dayIndex < 6 {
            Divider()
        }
    }

    @ViewBuilder
    private func parsedDayContent(parsed: ParsedDayData, dayName: String) -> some View {
        switch categoryId {
        case "eating":
            Text(parsed.eating.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(parsed.eating.details, id: \.self) { detail in
                HStack(alignment: .top, spacing: 6) {
                    Text("·").foregroundStyle(.tertiary)
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
            }
        case "naps":
            Text(parsed.naps.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(parsed.naps.details, id: \.self) { detail in
                HStack(alignment: .top, spacing: 6) {
                    Text("·").foregroundStyle(.tertiary)
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
            }
            if let sleep = currentWeek?.sleepNotes[dayName] {
                HStack(spacing: 12) {
                    if !sleep.wakeUp.isEmpty {
                        Label(sleep.wakeUp, systemImage: "sunrise.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    if !sleep.bedTime.isEmpty {
                        Label(sleep.bedTime, systemImage: "moon.fill")
                            .font(.caption)
                            .foregroundStyle(.indigo)
                    }
                }
            }
        case "potty":
            Text(parsed.potty.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(parsed.potty.details, id: \.self) { detail in
                HStack(alignment: .top, spacing: 6) {
                    Text("·").foregroundStyle(.tertiary)
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
            }
        case "mood":
            Text(parsed.mood)
                .font(.caption)
                .foregroundStyle(.secondary)
            if !parsed.activities.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "figure.play")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                    Text(parsed.activities.joined(separator: ", "))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                }
            }
            if !parsed.teacherNotes.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "note.text")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                    Text(parsed.teacherNotes)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                }
            }
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private func healthDayContent(dayName: String) -> some View {
        if let health = currentWeek?.healthNotes[dayName] {
            Text(health.status.rawValue)
                .font(.caption)
                .foregroundStyle(.secondary)
            if !health.symptoms.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "stethoscope")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                    Text(health.symptoms)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            Text("No data")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Data Helpers

    private var overallRating: StatusRating {
        let ratings = DateHelpers.dayNames.map { ratingForDay($0) }.filter { $0 != .none }
        if ratings.isEmpty { return .none }
        if ratings.contains(.red) { return .red }
        if ratings.contains(.yellow) { return .yellow }
        return .green
    }

    private func ratingForDay(_ dayName: String) -> StatusRating {
        if categoryId == "health" {
            return currentWeek?.healthNotes[dayName]?.status.rating ?? .none
        }
        guard let parsed = currentWeek?.parsedEntries[dayName] else { return .none }
        switch categoryId {
        case "eating": return parsed.eating.rating
        case "naps": return parsed.naps.rating
        case "potty": return parsed.potty.rating
        case "mood": return parsed.moodRating
        default: return .none
        }
    }

    private var hasCategoryData: Bool {
        DateHelpers.dayNames.contains { ratingForDay($0) != .none }
    }

    // MARK: - AI Summary Logic

    private func loadCachedOrGenerate() {
        guard hasCategoryData else { return }

        if let cached = currentWeek?.categorySummaries[categoryId],
           cached.generatedAt >= (currentWeek?.updatedAt ?? Date.distantPast) {
            summaryText = cached.text
        } else {
            Task { await generateSummary(force: false) }
        }
    }

    private func generateSummary(force: Bool) async {
        guard hasCategoryData else { return }

        if !force,
           let cached = currentWeek?.categorySummaries[categoryId],
           cached.generatedAt >= (currentWeek?.updatedAt ?? Date.distantPast) {
            summaryText = cached.text
            return
        }

        isGenerating = true
        errorMessage = nil

        let weekData = buildCategoryWeekData()

        do {
            let summary = try await apiService.generateCategorySummary(
                categoryId: categoryId,
                weekData: weekData
            )
            summaryText = summary

            if let week = currentWeek {
                var summaries = week.categorySummaries
                summaries[categoryId] = CachedSummary(text: summary, generatedAt: Date())
                week.categorySummaries = summaries
                try? modelContext.save()
            }
        } catch {
            errorMessage = "Couldn't generate summary. Tap to retry."
        }

        isGenerating = false
    }

    private func buildCategoryWeekData() -> String {
        var data = ""
        for dayIndex in 0..<7 {
            let dayName = DateHelpers.dayNames[dayIndex]

            if categoryId == "health" {
                if let health = currentWeek?.healthNotes[dayName] {
                    data += "\(dayName): \(health.status.rawValue)"
                    if !health.symptoms.isEmpty {
                        data += " — Symptoms: \(health.symptoms)"
                    }
                    data += "\n"
                }
                continue
            }

            guard let parsed = currentWeek?.parsedEntries[dayName] else { continue }

            switch categoryId {
            case "eating":
                data += "\(dayName): \(parsed.eating.summary) [\(parsed.eating.rating.rawValue)]\n"
                if !parsed.eating.details.isEmpty {
                    data += "  Details: \(parsed.eating.details.joined(separator: "; "))\n"
                }
            case "naps":
                data += "\(dayName): \(parsed.naps.summary) [\(parsed.naps.rating.rawValue)]\n"
                if !parsed.naps.details.isEmpty {
                    data += "  Details: \(parsed.naps.details.joined(separator: "; "))\n"
                }
                if let sleep = currentWeek?.sleepNotes[dayName] {
                    data += "  Home sleep: Wake \(sleep.wakeUp), Bed \(sleep.bedTime)\n"
                }
            case "potty":
                data += "\(dayName): \(parsed.potty.summary) [\(parsed.potty.rating.rawValue)]\n"
                if !parsed.potty.details.isEmpty {
                    data += "  Details: \(parsed.potty.details.joined(separator: "; "))\n"
                }
            case "mood":
                data += "\(dayName): \(parsed.mood) [\(parsed.moodRating.rawValue)]\n"
                if !parsed.activities.isEmpty {
                    data += "  Activities: \(parsed.activities.joined(separator: ", "))\n"
                }
                if !parsed.teacherNotes.isEmpty {
                    data += "  Teacher notes: \(parsed.teacherNotes)\n"
                }
            default:
                break
            }
        }
        return data
    }
}
