import AppKit
import CacheBarCore
import Foundation
import Observation
import UserNotifications

/// 前台也出横幅：willPresent 默认静默，显式放行 banner + sound。
final public class NotificationPresenter: NSObject, UNUserNotificationCenterDelegate {
    public func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}

@MainActor
public func attachNotifications(to store: SessionStore, status: NotificationStatus) {
    let systemCenter = UNUserNotificationCenter.current()
    let scheduler = NotificationScheduler(center: SystemNotificationCenter(center: systemCenter, status: status))
    Task {
        do {
            let granted = try await systemCenter.requestAuthorization(options: [.alert, .sound])
            status.setAuthorization(granted ? .authorized : .denied)
            NSLog("CacheBar notification authorization granted=%d", granted)
            observeNotifications(store: store, scheduler: scheduler, status: status)
        } catch {
            status.setAuthorization(.denied)
            status.record(failure: "通知授权失败：\(error.localizedDescription)")
            NSLog("CacheBar notification authorization failed: %@", error.localizedDescription)
        }
    }
}

/// 读取系统当前的授权状态并刷新显示；notificationSettings 不弹窗。
@MainActor
public func refreshAuthorizationDisplay(status: NotificationStatus) async {
    let settings = await UNUserNotificationCenter.current().notificationSettings()
    let mapped: NotificationStatus.Authorization
    switch settings.authorizationStatus {
    case .authorized, .provisional, .ephemeral: mapped = .authorized
    case .denied: mapped = .denied
    case .notDetermined: mapped = .undetermined
    @unknown default: mapped = .undetermined
    }
    status.setAuthorization(mapped)
    if mapped == .authorized { status.clearFailure() }
}

@MainActor
public func sendTestNotification(status: NotificationStatus) {
    let content = UNMutableNotificationContent()
    content.title = "CacheBar 测试通知"
    content.body = "看到这条横幅说明通知链路是通的。"
    content.sound = .default
    let request = UNNotificationRequest(identifier: "cachebar-test-\(UUID().uuidString)", content: content,
                                        trigger: UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false))
    Task {
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            status.record(failure: "测试通知发送失败：\(error.localizedDescription)")
            NSLog("CacheBar test notification failed: %@", error.localizedDescription)
        }
    }
}

@MainActor
public func openNotificationSettings() {
    let identifier = Bundle.main.bundleIdentifier ?? ""
    guard let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension?\(identifier)") else { return }
    NSWorkspace.shared.open(url)
}

@MainActor
private func observeNotifications(store: SessionStore, scheduler: NotificationScheduler, status: NotificationStatus) {
    withObservationTracking {
        scheduler.refresh(sessions: store.sessions)
    } onChange: {
        Task { @MainActor in observeNotifications(store: store, scheduler: scheduler, status: status) }
    }
    status.setPendingCount(scheduler.pendingCount)
}

@MainActor
private final class SystemNotificationCenter: LocalNotificationCenter {
    private let center: UNUserNotificationCenter
    private let status: NotificationStatus

    init(center: UNUserNotificationCenter, status: NotificationStatus) {
        self.center = center
        self.status = status
    }

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
            catch {
                status.record(failure: "通知排程失败：\(error.localizedDescription)")
                NSLog("CacheBar notification scheduling failed: %@", error.localizedDescription)
            }
        }
    }

    func remove(identifiers: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}
