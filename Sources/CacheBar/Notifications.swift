import CacheBarCore
import Foundation
import Observation
import UserNotifications

@MainActor
func attachNotifications(to store: SessionStore) {
    let systemCenter = UNUserNotificationCenter.current()
    let scheduler = NotificationScheduler(center: SystemNotificationCenter(center: systemCenter))
    Task {
        do {
            _ = try await systemCenter.requestAuthorization(options: [.alert, .sound])
            observeNotifications(store: store, scheduler: scheduler)
        } catch {
            NSLog("CacheBar notification authorization failed: %@", error.localizedDescription)
        }
    }
}

@MainActor
private func observeNotifications(store: SessionStore, scheduler: NotificationScheduler) {
    withObservationTracking {
        scheduler.refresh(sessions: store.sessions)
    } onChange: {
        Task { @MainActor in observeNotifications(store: store, scheduler: scheduler) }
    }
}

@MainActor
private final class SystemNotificationCenter: LocalNotificationCenter {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter) { self.center = center }

    func add(_ notification: ScheduledNotification) {
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.body
        content.sound = .default
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: notification.fireAt)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: notification.identifier, content: content, trigger: trigger)
        Task {
            do { try await center.add(request) }
            catch { NSLog("CacheBar notification scheduling failed: %@", error.localizedDescription) }
        }
    }

    func remove(identifiers: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}
