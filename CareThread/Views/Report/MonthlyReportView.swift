//
//  MonthlyReportView.swift
//  CareThread
//
//  Created by Gian Ramirez on 3/18/26.
//

import SwiftUI
import SwiftData

struct MonthlyReportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ClaudeAPIService.self) var apiService

    @Query private var allWeeks: [WeekEntry]
    @Query private var allSettings: [AppSettings]
    @Query private var allMonthlyReports: [MonthlyReport]

    @State private var selectedMonth: String = ""
    @State private var toastMessage: String?
    @State private var toastIsError = false

    private var settings: AppSettings? { allSettings.first }

    private var currentMonthlyReport: MonthlyReport? {
        allMonthlyReports.first { $0.monthId == selectedMonth }
    }

    private var monthOptions: [(label: String, value: String)] {
        DateHelpers.monthOptions()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
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

    private func generateMonthlyReport() async {
        let mondayKeys = DateHelpers.mondaysInMonth(selectedMonth)

        let weeklyReports = mondayKeys.compactMap { key -> String? in
            guard let week = allWeeks.first(where: { $0.weekId == key }),
                  let report = week.report, !report.isEmpty else { return nil }
            return "### Week of \(key)\n\(report)"
        }

        guard !weeklyReports.isEmpty else {
            toastIsError = true
            toastMessage = "No weekly reports found for this month."
            return
        }

        do {
            let report = try await apiService.generateMonthlyReport(
                weeklyReports: weeklyReports.joined(separator: "\n\n---\n\n"),
                therapyContext: settings?.therapySchedule ?? ""
            )

            if let existing = currentMonthlyReport {
                existing.report = report
                existing.createdAt = Date()
            } else {
                modelContext.insert(MonthlyReport(monthId: selectedMonth, report: report))
            }

            toastIsError = false; toastMessage = "Monthly report generated!"
        } catch {
            toastIsError = true; toastMessage = "Couldn't generate monthly report."
        }
    }
}
