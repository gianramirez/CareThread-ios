import Foundation
import UserNotifications

// MARK: - NotificationService
// ─────────────────────────────────────────────────────────────────────
// Handles push notifications — your "Native Enhancement" requirement.
//
// iOS LOCAL notifications (no server needed!):
// Unlike web push notifications which require a service worker and
// a push server, iOS local notifications are scheduled directly on
// the device. No backend needed for daily reminders.
//
// The flow:
// 1. Request permission from the user (one-time prompt)
// 2. Schedule a daily recurring notification at a specific time
// 3. iOS handles delivery even if the app is closed
//
// In Java terms: This is like scheduling a cron job, but it runs on
// the device OS instead of a server.
//
// IMPORTANT: You must add "Push Notifications" capability in Xcode:
// Targets → Signing & Capabilities → + Capability → Push Notifications
// (For local notifications you technically don't need the capability,
// but it's good practice to add it.)
// ─────────────────────────────────────────────────────────────────────

class NotificationService {
    static let shared = NotificationService()  // Singleton pattern (like @Component in Spring)

    private let center = UNUserNotificationCenter.current()

    // Notification identifiers
    private let eveningReminderId = "carethread-evening-reminder"

    // MARK: - Request Permission

    /// Ask the user for notification permission.
    /// Call this early in the app lifecycle (e.g., on first launch).
    /// Returns true if permission was granted.
    ///
    /// iOS will show the native "Allow Notifications?" dialog.
    /// The user can change this later in Settings > Notifications.
    func requestPermission() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(
                options: [.alert, .sound, .badge]
            )
            return granted
        } catch {
            print("Notification permission error: \(error)")
            return false
        }
    }

    // MARK: - Schedule Evening Reminder

    /// Schedule a daily reminder to paste the daycare sheet.
    /// Default: 6:00 PM every weekday (Mon-Fri).
    ///
    /// `UNCalendarNotificationTrigger` is like a cron expression:
    ///   hour: 18, minute: 0, weekday: 2 (Mon) through 6 (Fri)
    ///
    /// We schedule 5 separate notifications (one per weekday) because
    /// iOS doesn't support "Mon-Fri" as a single trigger.
    func scheduleEveningReminder(hour: Int = 18, minute: Int = 0) {
        // Cancel existing reminders first
        cancelEveningReminder()

        let content = UNMutableNotificationContent()
        content.title = "CareThread"
        content.body = "Don't forget to log today's daycare sheet! 📋"
        content.sound = .default

        // Schedule for each weekday (2=Mon, 3=Tue, ..., 6=Fri in Apple's calendar)
        for weekday in 2...6 {
            var dateComponents = DateComponents()
            dateComponents.hour = hour
            dateComponents.minute = minute
            dateComponents.weekday = weekday

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: dateComponents,
                repeats: true  // Repeat every week
            )

            let request = UNNotificationRequest(
                identifier: "\(eveningReminderId)-\(weekday)",
                content: content,
                trigger: trigger
            )

            center.add(request) { error in
                if let error {
                    print("Failed to schedule notification: \(error)")
                }
            }
        }

        print("Evening reminders scheduled for \(hour):\(String(format: "%02d", minute)) Mon-Fri")
    }

    // MARK: - Cancel Reminders

    /// Cancel all evening reminders.
    func cancelEveningReminder() {
        let ids = (2...6).map { "\(eveningReminderId)-\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    // MARK: - Check Status

    /// Check if notifications are currently authorized.
    func checkPermissionStatus() async -> UNAuthorizationStatus {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus
    }
}
