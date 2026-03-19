import SwiftUI
import SwiftData

// MARK: - ContentView
// ─────────────────────────────────────────────────────────────────────
// The root view that handles PIN lock + main content.
//
// In React, your App component checked `unlocked` state and showed
// either <PinScreen> or the main app. Same pattern here.
//
// This is also where we create the @StateObject for the API service
// and inject it into the environment for all child views to access.
// ─────────────────────────────────────────────────────────────────────

struct ContentView: View {
    // Create and own the API service — this is the @Bean definition
    @StateObject private var apiService = ClaudeAPIService()

    // PIN lock state
    @State private var isUnlocked = false

    // Query settings to check if PIN is set
    @Query private var allSettings: [AppSettings]

    private var pinCode: String {
        allSettings.first?.pinCode ?? ""
    }

    private var hasPinSet: Bool {
        !pinCode.isEmpty
    }

    var body: some View {
        Group {
            if hasPinSet && !isUnlocked {
                PinLockView(correctPin: pinCode, isUnlocked: $isUnlocked)
            } else {
                MainTabView()
            }
        }
        // Inject the API service into the environment.
        // Every child view can access it with @EnvironmentObject.
        // Like wrapping your React tree in <APIContext.Provider value={apiService}>
        .environmentObject(apiService)
        // Auto-unlock if no PIN is set
        .onAppear {
            if !hasPinSet {
                isUnlocked = true
            }
        }
    }
}
