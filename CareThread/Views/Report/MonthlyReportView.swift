import SwiftUI
import SwiftData

// MARK: - MonthlyReportView
// ─────────────────────────────────────────────────────────────────────
// Maps to your React Monthly tab.
//
// In React: Month selector dropdown → Generate button → Report display
// In SwiftUI: We use a Picker for the month selector (native dropdown).
// ─────────────────────────────────────────────────────────────────────

struct MonthlyReportView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var apiService: ClaudeAPIService

    @Query private var allWeeks: [WeekEntry]
    @Query private var allSettings: [AppSettings]
    @Query private var allMonthlyReports: [MonthlyReport]

    @State private var selectedMonth: String = ""
    @State private var toastMessage: String?
    @State private var toastIsError = false

    private var settings: AppSettings? {
        allSettings.first
    }

    private var currentMonthlyReport: MonthlyReport? {
        allMonthlyReports.first { $0.monthId == selectedMonth }
    }

    private var monthOptions: [(label: String, value: String)] {
        DateHelpers.monthOptions()
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Month selector + generate button
            HStack(spacing: 12) {
                // Picker is SwiftUI's <select> — with .menu style it shows as a dropdown
                Picker("Month", selection: $selectedMonth) {
                    ForEach(monthOptions, id: \.value) { option in
                        Text(option.label).tag(option.value)
                    }
                }
                .pickerStyle(.menu)

                Button {
                    Task { await generateMonthlyReport() }
                } label: {
                    Label("Generate", systemImage: "doc.text.magnifyingglass")
                        .font(.subheadline)
                }
                .buttonStyle(.borderedProminent)
                .disabled(apiService.isLoading || selectedMonth.isEmpty)
            }
            .padding()

            if let report = currentMonthlyReport {
                // Report display
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 12) {
                            ShareLink(item: report.report) {
                                Label("Share", systemImage: "square.and.arrow.up")
                                    .font(.subheadline)
                            }
                            .buttonStyle(.bordered)

                            Button {
                                UIPasteboard.general.string = report.report
                                toastMessage = "Copied!"
                            } label: {
                                Label("Copy", systemImage: "doc.on.doc")
                                    .font(.subheadline)
                            }
                            .buttonStyle(.bordered)

                            Spacer()
                        }

                        Divider()

                        Text(LocalizedStringKey(report.report))
                            .font(.subheadline)
                            .textSelection(.enabled)
                    }
                    .padding()
                }
            } else {
                // Empty state
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 48))
                        .foregroundStyle(.tertiary)
                    Text("No monthly report yet")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Select a month and generate a report. You need at least one weekly report in that month.")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    Spacer()
                }
            }
        }
        .toast(message: $toastMessage, isError: toastIsError)
        .onAppear {
            if selectedMonth.isEmpty, let first = monthOptions.first {
                selectedMonth = first.value
            }
        }
    }

    // MARK: - Generate Monthly Report

    /// Maps to your React generateMonthlyReport().
    /// Fetches all weekly reports for the selected month, sends them to Claude.
    private func generateMonthlyReport() async {
        let mondayKeys = DateHelpers.mondaysInMonth(selectedMonth)

        // Gather weekly reports for those Mondays
        let weeklyReports = mondayKeys.compactMap { key -> String? in
            guard let week = allWeeks.first(where: { $0.weekId == key }),
                  let report = week.report, !report.isEmpty else {
                return nil
            }
            return "### Week of \(key)\n\(report)"
        }

        guard !weeklyReports.isEmpty else {
            toastIsError = true
            toastMessage = "No weekly reports found for this month."
            return
        }

        let combinedReports = weeklyReports.joined(separator: "\n\n---\n\n")

        do {
            let report = try await apiService.generateMonthlyReport(
                weeklyReports: combinedReports,
                therapyContext: settings?.therapySchedule ?? ""
            )

            // Save or update the monthly report
            if let existing = currentMonthlyReport {
                existing.report = report
                existing.createdAt = Date()
            } else {
                let newReport = MonthlyReport(monthId: selectedMonth, report: report)
                modelContext.insert(newReport)
            }

            toastIsError = false
            toastMessage = "Monthly report generated!"
        } catch {
            toastIsError = true
            toastMessage = "Couldn't generate monthly report."
            print("Monthly report error: \(error)")
        }
    }
}
