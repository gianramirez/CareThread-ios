import SwiftUI

// MARK: - AppTab Enum
// ─────────────────────────────────────────────────────────────────────
// Maps to your React `view` state: "dashboard" | "entry" | "report" | "monthly" | "settings"
//
// In React, you switched views with: {view === "dashboard" && <Dashboard />}
// In SwiftUI, TabView does this automatically — you bind it to a @State
// and SwiftUI handles the tab switching, animations, and tab bar rendering.
// ─────────────────────────────────────────────────────────────────────

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
// ─────────────────────────────────────────────────────────────────────
// The main container — equivalent to your React App component's render().
//
// In React, you had:
//   - Header (week nav + tab buttons + progress bar)
//   - Content area (conditionally rendered based on `view` state)
//
// In SwiftUI, TabView gives us native iOS tab bar navigation.
// The week navigator sits in a NavigationStack (gives us the iOS nav bar).
//
// KEY CONCEPT — @StateObject vs @EnvironmentObject:
//
// @StateObject: Creates and OWNS the object. Like creating a context
//   provider at the top of your React tree.
//   → Used here to create the ClaudeAPIService
//
// @EnvironmentObject: Reads a shared object from the environment.
//   Like useContext() in React — it reaches up the view hierarchy to
//   find the object.
//   → Used in child views to access the service
//
// In Spring Boot terms: @StateObject is like @Bean creation,
// @EnvironmentObject is like @Autowired injection.
// ─────────────────────────────────────────────────────────────────────

struct MainTabView: View {
    // Shared state — owned here, injected into child views
    @State private var currentMonday = DateHelpers.mondayOfWeek(containing: Date())
    @State private var selectedTab: AppTab = .dashboard
    @State private var activeDay: Int = 0

    // Loading overlay
    @EnvironmentObject var apiService: ClaudeAPIService

    var body: some View {
        ZStack {
            // The TabView — SwiftUI's native tab bar controller
            // Each tab gets its own NavigationStack for proper nav bar behavior
            TabView(selection: $selectedTab) {
                // Dashboard Tab
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
                .tabItem {
                    Label(AppTab.dashboard.rawValue, systemImage: AppTab.dashboard.icon)
                }
                .tag(AppTab.dashboard)

                // Log Day Tab
                NavigationStack {
                    EntryView(
                        currentMonday: $currentMonday,
                        activeDay: $activeDay
                    )
                    .navigationTitle(DateHelpers.dayNames[activeDay])
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { weekNavigatorToolbar }
                }
                .tabItem {
                    Label(AppTab.logDay.rawValue, systemImage: AppTab.logDay.icon)
                }
                .tag(AppTab.logDay)

                // Report Tab
                NavigationStack {
                    ReportView(currentMonday: $currentMonday)
                        .navigationTitle("Weekly Report")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar { weekNavigatorToolbar }
                }
                .tabItem {
                    Label(AppTab.report.rawValue, systemImage: AppTab.report.icon)
                }
                .tag(AppTab.report)

                // Monthly Tab
                NavigationStack {
                    MonthlyReportView()
                        .navigationTitle("Monthly Report")
                        .navigationBarTitleDisplayMode(.inline)
                }
                .tabItem {
                    Label(AppTab.monthly.rawValue, systemImage: AppTab.monthly.icon)
                }
                .tag(AppTab.monthly)

                // Settings Tab
                NavigationStack {
                    SettingsView(
                        currentMonday: $currentMonday,
                        isUnlocked: .constant(true)  // Will be connected to PIN lock
                    )
                    .navigationTitle("Settings")
                    .navigationBarTitleDisplayMode(.inline)
                }
                .tabItem {
                    Label(AppTab.settings.rawValue, systemImage: AppTab.settings.icon)
                }
                .tag(AppTab.settings)
            }
            .tint(AppTheme.accent)  // Tab bar tint color

            // Loading overlay — shown on top of everything when API is working
            if apiService.isLoading {
                LoadingOverlay(message: apiService.loadingMessage)
            }
        }
    }

    // MARK: - Week Navigator Toolbar

    /// Inline week navigation in the toolbar area.
    /// In React this was the header with < Week of ... > arrows.
    @ToolbarContentBuilder
    private var weekNavigatorToolbar: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            WeekNavigator(currentMonday: $currentMonday)
        }
    }
}
