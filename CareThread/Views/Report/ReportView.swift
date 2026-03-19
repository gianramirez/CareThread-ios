import SwiftUI
import SwiftData

// MARK: - ReportView
// ─────────────────────────────────────────────────────────────────────
// Maps to your React Report tab — shows weekly parent + care team reports.
//
// In React: Two sub-tabs ("Full Report" / "Care Team") with:
//   - Report text (pre-wrapped)
//   - Copy button
//   - Regenerate button
//
// NEW SWIFTUI CONCEPT — Native Share Sheet:
// Instead of just a "Copy" button, iOS apps use UIActivityViewController
// (the native share sheet). In SwiftUI, the ShareLink view handles this
// automatically — users can share via Messages, Mail, Notes, etc.
// This is one of your "Native Enhancements" requirements!
// ─────────────────────────────────────────────────────────────────────

struct ReportView: View {
    @Binding var currentMonday: Date

    @Query private var allWeeks: [WeekEntry]
    @Query private var allSettings: [AppSettings]
    @EnvironmentObject var apiService: ClaudeAPIService

    @State private var selectedReportType: ReportType = .parent
    @State private var toastMessage: String?

    enum ReportType: String, CaseIterable {
        case parent = "Full Report"
        case careTeam = "Care Team"
    }

    private var currentWeek: WeekEntry? {
        let key = DateHelpers.weekKey(for: currentMonday)
        return allWeeks.first { $0.weekId == key }
    }

    private var settings: AppSettings? {
        allSettings.first
    }

    private var currentReport: String? {
        switch selectedReportType {
        case .parent: return currentWeek?.report
        case .careTeam: return currentWeek?.careReport
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Report type toggle
            Picker("Report Type", selection: $selectedReportType) {
                ForEach(ReportType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            if let report = currentReport, !report.isEmpty {
                // Report content
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Action buttons
                        HStack(spacing: 12) {
                            // Native Share Sheet — your "Native Share Sheet" requirement!
                            // ShareLink is SwiftUI's wrapper around UIActivityViewController.
                            // One line of code gives you Messages, Mail, Files, AirDrop, etc.
                            ShareLink(item: report) {
                                Label("Share", systemImage: "square.and.arrow.up")
                                    .font(.subheadline)
                            }
                            .buttonStyle(.bordered)

                            // Copy to clipboard
                            Button {
                                UIPasteboard.general.string = report
                                toastMessage = "Copied to clipboard!"
                            } label: {
                                Label("Copy", systemImage: "doc.on.doc")
                                    .font(.subheadline)
                            }
                            .buttonStyle(.bordered)

                            Spacer()

                            // Regenerate
                            Button {
                                Task { await regenerateReports() }
                            } label: {
                                Label("Regenerate", systemImage: "arrow.clockwise")
                                    .font(.subheadline)
                            }
                            .buttonStyle(.bordered)
                            .disabled(apiService.isLoading)
                        }

                        Divider()

                        // Report text — rendered as markdown
                        // Text() with markdown support is built into SwiftUI!
                        // In React you rendered this as <pre> with white-space: pre-wrap
                        Text(LocalizedStringKey(report))
                            .font(.subheadline)
                            .textSelection(.enabled)  // Allow long-press to select text
                    }
                    .padding()
                }
            } else {
                // Empty state
                emptyState
            }
        }
        .toast(message: $toastMessage)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            Text("No report yet")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Log some days first, then generate a report from the Dashboard.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
        }
    }

    // MARK: - Actions

    private func regenerateReports() async {
        guard let week = currentWeek, week.filledDayCount > 0 else { return }

        // Build daily data (same logic as in DashboardView)
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
            if let note = week.eveningNotes[dayName], !note.isEmpty {
                dailyData += "- Evening Note: \(note)\n"
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
            week.report = reports.parentReport
            week.careReport = reports.careReport
            week.updatedAt = Date()
            toastMessage = "Reports regenerated!"
        } catch {
            toastMessage = "Couldn't regenerate — try again."
        }
    }
}
