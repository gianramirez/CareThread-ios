//
//  ContentView.swift
//  CareThread
//
//  Created by Gian Ramirez on 3/18/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allSettings: [AppSettings]
    @State private var isUnlocked = false

    @State private var apiService = ClaudeAPIService()

    private var isLockEnabled: Bool {
        guard let settings = allSettings.first else { return false }
        return settings.isLockEnabled
    }

    var body: some View {
        MainTabView()
            .environment(apiService)
            .fullScreenCover(isPresented: Binding(
                get: { isLockEnabled && !isUnlocked },
                set: { if !$0 { isUnlocked = true } }
            )) {
                BiometricLockView(isUnlocked: $isUnlocked)
            }
            .onAppear {
                #if DEBUG
                SampleData.seedIfEmpty(context: modelContext)
                #endif
            }
    }
}
