import Testing
@testable import CacheBarCore

@Suite("NotificationStatusTests")
@MainActor
struct NotificationStatusTests {
    @Test("authorization starts undetermined and transitions through all three states")
    func authorizationStates() {
        let status = NotificationStatus()
        #expect(status.authorization == .undetermined)
        status.setAuthorization(.authorized)
        #expect(status.authorization == .authorized)
        status.setAuthorization(.denied)
        #expect(status.authorization == .denied)
        status.setAuthorization(.undetermined)
        #expect(status.authorization == .undetermined)
    }

    @Test("failure messages pass through verbatim and the latest one wins")
    func failurePassthrough() {
        let status = NotificationStatus()
        status.record(failure: "通知授权失败：Notifications are not allowed for this application")
        #expect(status.lastFailure == "通知授权失败：Notifications are not allowed for this application")
        status.record(failure: "通知排程失败：second failure")
        #expect(status.lastFailure == "通知排程失败：second failure")
        status.clearFailure()
        #expect(status.lastFailure == nil)
    }

    @Test("pending count reflects the latest scheduler output")
    func pendingCount() {
        let status = NotificationStatus()
        #expect(status.pendingCount == 0)
        status.setPendingCount(4)
        #expect(status.pendingCount == 4)
        status.setPendingCount(2)
        #expect(status.pendingCount == 2)
    }
}
