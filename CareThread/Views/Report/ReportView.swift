//
//  ReportView.swift
//  CareThread
//
//  Created by Gian Ramirez on 3/18/26.
//

import SwiftUI
import SwiftData

struct ReportView: View {
    @Binding var currentMonday: Date

    @Environment(ClaudeAPIService.self) var apiService
    @Query private var allWeeks: [WeekEntry]

    @State private var reportType: ReportType = .parent
    @State private var toastMessage: String?

    enum ReportType: String, CaseIterable {
        case parent = "Full Report"
        case careTeam = "Care Team"
    }

    private var weekKey: String { DateHelpers.weekKey(for: currentMonday) }
    private var currentWeek: WeekEntry? { allWeeks.first { $0.weekId == weekKey } }

    private var currentReport: String? {
        switch reportType {
        case .parent: return currentWeek?.report
        case .careTeam: return currentWeek?.careReport
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Report Type", selection: $reportType) {
                ForEach(ReportType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            if let report = currentReport, !report.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 12) {
                            ShareLink(item: report) {
                                Label("Share", systemImage: "square.and.arrow.up")
                                    .font(.subheadline)
                            }
                            .buttonStyle(.bordered)

                            Button {
                                UIPasteboard.general.string = report
                                toastMessage = "Copied!"
                            } label: {
                                Label("Copy", systemImage: "doc.on.doc")
                                    .font(.subheadline)
                            }
                            .buttonStyle(.bordered)

                            Spacer()
                        }

                        Divider()

                        Text(LocalizedStringKey(report))
                            .font(.subheadline)
                            .textSelection(.enabled)
                    }
                    .padding()
                }
            } else {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "doc.text")
                        .font(.system(size: 48))
                        .foregroundStyle(.tertiary)
                    Text("No report yet")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Generate a weekly report from the Dashboard once you have at least one day logged.")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    Spacer()
                }
            }
        }
        .toast(message: $toastMessage)
    }
}
