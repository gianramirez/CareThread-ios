//
//  CareThreadApp.swift
//  CareThread
//
//  Created by Gian Ramirez on 3/18/26.
//

import SwiftUI
import SwiftData

@main
struct CareThreadApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
            WeekEntry.self,
            AppSettings.self,
            MonthlyReport.self,
        ])
    }
}
