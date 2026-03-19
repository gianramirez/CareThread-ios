//
//  MainTabView.swift
//  CareThread
//
//  Created by Gian Ramirez on 3/18/26.
//

import SwiftUI

// MARK: - AppTab Enum

enum AppTab: String, CaseIterable {
    case dashboard = "Dashboard"
    case logDay = "Log Day"
    case report = "Report"
    case monthly = "Monthly"
    case settings = "Settings"

    var icon: String {
        switch self {
        case .dashboard: return "square.grid.2x2"
        case .logDay: return "plus.circle"
        case .report: return "doc.text"
        case .monthly: return "calendar"
        case .settings: return "gearshape"
        }
    }
}

// MARK: - MainTabView

struct MainTabView: View {
    @State private var currentMonday = DateHelpers.mondayOfWeek(containing: Date())
    @State private var selectedTab: AppTab = .dashboard
    @State private var activeDay: Int = 0

    @Environment(ClaudeAPIService.self) var apiService

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                NavigationStack {
                    DashboardView(
                        currentMonday: $currentMonday,
                        selectedTab: $selectedTab,
                        activeDay: $activeDay
                    )
                    .navigationTitle("CareThread")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { weekNavigatorToolbar }
                }
                .tabItem { Label(AppTab.dashboard.rawValue, systemImage: AppTab.dashboard.icon) }
                .tag(AppTab.dashboard)

                NavigationStack {
                    EntryView(currentMonday: $currentMonday, activeDay: $activeDay)
                        .navigationTitle(DateHelpers.dayNames[activeDay])
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar { weekNavigatorToolbar }
                }
                .tabItem { Label(AppTab.logDay.rawValue, systemImage: AppTab.logDay.icon) }
                .tag(AppTab.logDay)

                NavigationStack {
                    ReportView(currentMonday: $currentMonday)
                        .navigationTitle("Weekly Report")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar { weekNavigatorToolbar }
                }
                .tabItem { Label(AppTab.report.rawValue, systemImage: AppTab.report.icon) }
                .tag(AppTab.report)

                NavigationStack {
                    MonthlyReportView()
                        .navigationTitle("Monthly Report")
                        .navigationBarTitleDisplayMode(.inline)
                }
                .tabItem { Label(AppTab.monthly.rawValue, systemImage: AppTab.monthly.icon) }
                .tag(AppTab.monthly)

                NavigationStack {
                    SettingsView(currentMonday: $currentMonday, isUnlocked: .constant(true))
                        .navigationTitle("Settings")
                        .navigationBarTitleDisplayMode(.inline)
                }
                .tabItem { Label(AppTab.settings.rawValue, systemImage: AppTab.settings.icon) }
                .tag(AppTab.settings)
            }
            .tint(AppTheme.accent)

            if apiService.isLoading {
                LoadingOverlay(message: apiService.loadingMessage)
            }
        }
    }

    @ToolbarContentBuilder
    private var weekNavigatorToolbar: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            WeekNavigator(currentMonday: $currentMonday)
        }
    }
}
