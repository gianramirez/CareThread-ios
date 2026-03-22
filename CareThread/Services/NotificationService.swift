//
//  NotificationService.swift
//  CareThread
//
//  Created by Gian Ramirez on 3/18/26.
//

import Foundation
import UserNotifications

class NotificationService {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()
    private let eveningReminderId = "carethread-evening-reminder"

    func requestPermission() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func scheduleEveningReminder(hour: Int = 18, minute: Int = 0) {
        cancelEveningReminder()

        let content = UNMutableNotificationContent()
        content.title = "CareThread"
        content.body = "Don't forget to log today's daycare sheet!"
        content.sound = .default

        for weekday in 2...6 {
            var dateComponents = DateComponents()
            dateComponents.hour = hour
            dateComponents.minute = minute
            dateComponents.weekday = weekday

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: dateComponents,
                repeats: true
            )

            let request = UNNotificationRequest(
                identifier: "\(eveningReminderId)-\(weekday)",
                content: content,
                trigger: trigger
            )

            center.add(request)
        }
    }

    func cancelEveningReminder() {
        let ids = (2...6).map { "\(eveningReminderId)-\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    func checkPermissionStatus() async -> UNAuthorizationStatus {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus
    }
}
