//
//  ContentView.swift
//  CareThread
//
//  Created by Gian Ramirez on 3/18/26.
//

import SwiftUI
import SwiftData

// MARK: - ContentView
// ─────────────────────────────────────────────────────────────────────
// The root view — acts as a gate between the PIN lock and the main app.
//
// In React: Your top-level App component checked `unlocked` state and
// rendered either <PinScreen> or the main dashboard.
//
// In SwiftUI: We use a conditional view that shows PinLockView as a
// fullScreenCover (modal overlay) when the app is locked.
//
// KEY CONCEPT — @AppStorage:
// Like localStorage in the browser, @AppStorage reads/writes to
// UserDefaults (iOS's built-in key-value store). But unlike your React
// sessionStorage approach, UserDefaults persists across app launches.
// We use it here for lightweight settings; SwiftData handles the heavy data.
// ─────────────────────────────────────────────────────────────────────

struct ContentView: View {
    @Query private var allSettings: [AppSettings]
    @State private var isUnlocked = false

    @State private var apiService = ClaudeAPIService()

    private var hasPinSet: Bool {
        guard let settings = allSettings.first else { return false }
        return !settings.pinCode.isEmpty
    }

    var body: some View {
        MainTabView()
            .environment(apiService)
            // Show PIN lock as a full-screen modal when locked
            .fullScreenCover(isPresented: Binding(
                get: { hasPinSet && !isUnlocked },
                set: { if !$0 { isUnlocked = true } }
            )) {
                if let pin = allSettings.first?.pinCode {
                    PinLockView(correctPin: pin, isUnlocked: $isUnlocked)
                }
            }
    }
}
