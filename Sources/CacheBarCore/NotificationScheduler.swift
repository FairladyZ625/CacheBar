import Foundation

public struct ScheduledNotification: Equatable, Sendable {
    public let identifier: String
    public let fireAt: Date
    public let title: String
    public let body: String

    public init(identifier: String, fireAt: Date, title: String, body: String) {
        self.identifier = identifier
        self.fireAt = fireAt
        self.title = title
        self.body = body
    }
}

@MainActor
public protocol LocalNotificationCenter: AnyObject {
    func add(_ notification: ScheduledNotification)
    func remove(identifiers: [String])
}

@MainActor
public final class NotificationScheduler {
    public static let defaultThresholds: [TimeInterval] = [10 * 60, 2 * 60]

    private let center: LocalNotificationCenter
    private let thresholds: [TimeInterval]
    private let clock: @Sendable () -> Date
    private var scheduled: [String: ScheduledNotification] = [:]

    public init(center: LocalNotificationCenter, thresholds: [TimeInterval] = defaultThresholds, now: @escaping @Sendable () -> Date = Date.init) {
        self.center = center
        self.thresholds = thresholds
        clock = now
    }

    /// 当前期望保持排程的通知条数，面板状态区显示用。
    public var pendingCount: Int { scheduled.count }

    public func refresh(sessions: [SessionSnapshot]) {
        let now = clock()
        var desired: [String: ScheduledNotification] = [:]
        for session in sessions {
            guard let expiry = session.expiresAt, expiry > now else { continue }
            let project = session.projectDirectory.map { URL(filePath: $0).lastPathComponent }.flatMap { $0.isEmpty ? nil : $0 } ?? "Claude Code"
            let estimate = session.recacheTokensIfCold.map { "约 \($0.formatted()) tokens" } ?? "重建成本未知"
            for threshold in thresholds {
                let fireAt = expiry.addingTimeInterval(-threshold)
                guard fireAt > now else { continue }
                let id = "\(session.sessionID):\(Int(threshold))"
            desired[id] = ScheduledNotification(identifier: id, fireAt: fireAt, title: "缓存即将过期 · \(project)", body: "项目：\(project)；重新写入缓存：\(estimate)")
            }
        }

        let changed = scheduled.compactMap { id, old in desired[id] == old ? nil : id }.sorted()
        if !changed.isEmpty { center.remove(identifiers: changed) }
        for notification in desired.values.sorted(by: { $0.fireAt < $1.fireAt }) where scheduled[notification.identifier] != notification {
            center.add(notification)
        }
        scheduled = desired
    }
}
