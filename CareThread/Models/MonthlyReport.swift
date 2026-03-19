import Foundation
import SwiftData

// MARK: - MonthlyReport
// ─────────────────────────────────────────────────────────────────────
// Maps to your React `monthly_reports` table in Supabase.
// In React: { id: "2026-03", report: "## Monthly Summary...", created_at: ... }
//
// Simple model — just stores the generated report text keyed by month.
// ─────────────────────────────────────────────────────────────────────

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
