import Foundation
import Observation

/// 通知链路的可观察状态：授权三态、已排程条数、最近一次失败原因。
/// 应用层把系统事件写进来，面板底部状态区只消费展示，不承载判断。
@Observable @MainActor
public final class NotificationStatus {
    public enum Authorization: Equatable, Sendable {
        case undetermined
        case authorized
        case denied
    }

    public private(set) var authorization: Authorization = .undetermined
    public private(set) var pendingCount = 0
    public private(set) var lastFailure: String?

    public init() {}

    public func setAuthorization(_ value: Authorization) { authorization = value }
    public func setPendingCount(_ value: Int) { pendingCount = value }
    public func record(failure: String) { lastFailure = failure }
    public func clearFailure() { lastFailure = nil }
}
