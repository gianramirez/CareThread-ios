//
//  MonthlyReport.swift
//  CareThread
//
//  Created by Gian Ramirez on 3/18/26.
//

import Foundation
import SwiftData

@Model
final class MonthlyReport {
    @Attribute(.unique)
    var monthId: String  // Format: "YYYY-MM"

    var report: String
    var createdAt: Date

    init(monthId: String, report: String) {
        self.monthId = monthId
        self.report = report
        self.createdAt = Date()
    }
}
