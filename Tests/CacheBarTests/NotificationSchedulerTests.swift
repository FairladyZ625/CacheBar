import Foundation
import Testing
@testable import CacheBarCore

@Suite("NotificationSchedulerTests")
@MainActor
struct NotificationSchedulerTests {
@Test("schedules both reminders at their expiry offsets and stays quiet on repeated refresh")
func schedulesExpiryReminders() {
    let now = Date(timeIntervalSince1970: 1_000)
    let center = RecordingNotificationCenter()
    let scheduler = NotificationScheduler(center: center, now: { now })
    scheduler.refresh(sessions: [snapshot(expiry: now.addingTimeInterval(3_600))])
    #expect(center.added.map(\.identifier) == ["session:600", "session:120"])
    #expect(center.added.map(\.fireAt) == [now.addingTimeInterval(3_000), now.addingTimeInterval(3_480)])
    scheduler.refresh(sessions: [snapshot(expiry: now.addingTimeInterval(3_600))])
    #expect(center.added.count == 2)
    #expect(center.removed.isEmpty)
}

@Test("reschedules changed expiry and cancels notifications for removed sessions")
func reschedulesChangedExpiry() {
    let now = Date(timeIntervalSince1970: 1_000)
    let center = RecordingNotificationCenter()
    let scheduler = NotificationScheduler(center: center, now: { now })
    scheduler.refresh(sessions: [snapshot(expiry: now.addingTimeInterval(3_600))])
    scheduler.refresh(sessions: [snapshot(expiry: now.addingTimeInterval(4_000))])
    #expect(center.removed == ["session:120", "session:600"])
    #expect(center.added.suffix(2).map(\.fireAt) == [now.addingTimeInterval(3_400), now.addingTimeInterval(3_880)])
    scheduler.refresh(sessions: [])
    #expect(center.removed.suffix(2) == ["session:120", "session:600"])
}

@Test("does not schedule past reminders or expired sessions")
func skipsPastReminders() {
    let now = Date(timeIntervalSince1970: 1_000)
    let center = RecordingNotificationCenter()
    let scheduler = NotificationScheduler(center: center, now: { now })
    scheduler.refresh(sessions: [snapshot(expiry: now.addingTimeInterval(60)), snapshot(id: "expired", expiry: now)])
    #expect(center.added.isEmpty)
}

@Test("uses configured thresholds and includes project and recache token estimate")
func configuredThresholdsAndMessage() {
    let now = Date(timeIntervalSince1970: 1_000)
    let center = RecordingNotificationCenter()
    let scheduler = NotificationScheduler(center: center, thresholds: [300], now: { now })
    scheduler.refresh(sessions: [snapshot(expiry: now.addingTimeInterval(600))])
    #expect(center.added.count == 1)
    #expect(center.added[0].fireAt == now.addingTimeInterval(300))
    #expect(center.added[0].body.contains("ExampleProject"))
    #expect(center.added[0].body.contains("42,000"))
}
}

@MainActor
private final class RecordingNotificationCenter: LocalNotificationCenter {
    var added: [ScheduledNotification] = []
    var removed: [String] = []
    func add(_ notification: ScheduledNotification) { added.append(notification) }
    func remove(identifiers: [String]) { removed.append(contentsOf: identifiers) }
}

private func snapshot(id: String = "session", expiry: Date) -> SessionSnapshot {
    SessionSnapshot(sessionID: id, name: nil, projectDirectory: "/Users/example/ExampleProject", model: nil,
        cacheHitRatio: nil, cacheWarm: true, cacheTTL: .oneHour, expiresAt: expiry, recacheTokensIfCold: 42_000,
        fiveHourUsage: nil, fiveHourResetsAt: nil, sevenDayUsage: nil, sevenDayResetsAt: nil,
        contextTokens: nil, contextWindowTokens: nil, costUSD: nil, source: .statusline, updatedAt: .distantPast)
}
