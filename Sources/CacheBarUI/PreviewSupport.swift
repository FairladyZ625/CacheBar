import CacheBarCore
import SwiftUI

/// 仅调试用的预览开关（截图与布局联调）：CACHEBAR_PREVIEW=1 用假数据、不扫描用户目录；
/// CACHEBAR_COLOR_SCHEME=dark|light 在应用内切外观。截图渲染由 CacheBarPreview target 承担。
public struct PreviewMode: Sendable {
    public let isActive: Bool
    public let colorScheme: ColorScheme?
    public var sessions: [SessionSnapshot] { PreviewSessions.samples }

    public init(environment: [String: String]) {
        isActive = environment["CACHEBAR_PREVIEW"] == "1"
        switch environment["CACHEBAR_COLOR_SCHEME"] {
        case "dark": colorScheme = .dark
        case "light": colorScheme = .light
        default: colorScheme = nil
        }
    }

    public static let current = PreviewMode(environment: ProcessInfo.processInfo.environment)
}

extension NotificationStatus {
    /// 预览/截图用的授权态假状态：已授权、排程 4 条。
    public static var preview: NotificationStatus {
        let status = NotificationStatus()
        status.setAuthorization(.authorized)
        status.setPendingCount(4)
        return status
    }
}

/// 假会话样本：五条活跃（statusline 全字段 / transcript 兜底 nil 字段 / 临近过期两种阈值）
/// 加三条已过期（默认折叠），排序口径与 SessionStore 一致（未过期且最早过期优先，已过期垫底）。
public enum PreviewSessions {
    public static var samples: [SessionSnapshot] {
        return [
            statusline(id: 1, name: "重构 session store", ratio: 0.96, ttl: .fiveMinutes, expiresIn: 108,
                       recache: 187_400, five: 62, fiveResetIn: 2_580, seven: 31, sevenResetIn: 273_600,
                       context: 187_400, window: 200_000, cost: 8.47, updatedIn: -40),
            statusline(id: 2, name: "phase-1 plan 写作", ratio: 0.87, ttl: .oneHour, expiresIn: 545,
                       recache: 96_100, five: 62, fiveResetIn: 2_580, seven: 31, sevenResetIn: 273_600,
                       context: 96_100, window: 200_000, cost: 1.02, updatedIn: -700),
            statusline(id: 3, name: "CacheBar 界面开发", ratio: 0.92, ttl: .oneHour, expiresIn: 2_492,
                       recache: 148_300, five: 62, fiveResetIn: 2_580, seven: 31, sevenResetIn: 273_600,
                       context: 148_300, window: 200_000, cost: 4.21, updatedIn: -1_200),
            transcript(id: 4, directory: "/Users/dev/Projects/other-thing", ratio: 0.71, ttl: .oneHour,
                       expiresIn: 3_120, context: 64_000, updatedIn: -300),
            statusline(id: 5, name: "长会话 · 另一个项目", ratio: 0.99, ttl: .oneHour, expiresIn: 4_320,
                       recache: 172_000, five: 62, fiveResetIn: 2_580, seven: 31, sevenResetIn: 273_600,
                       context: 172_000, window: 200_000, cost: 21.3, updatedIn: -2_400),
            transcript(id: 6, directory: "/Users/dev/Tools/scripts", ratio: 0.45, ttl: .fiveMinutes,
                       expiresIn: -180, context: 12_400, updatedIn: -600),
            transcript(id: 7, directory: "/Users/dev/Playground/swift-chess", ratio: 0.38, ttl: .fiveMinutes,
                       expiresIn: -2_400, context: 8_300, updatedIn: -9_000),
            transcript(id: 8, directory: "/Users/dev/Projects/scratch", ratio: 0.52, ttl: .oneHour,
                       expiresIn: -7_200, context: 21_000, updatedIn: -12_000),
        ]
    }

    private static func statusline(id: Int, name: String, ratio: Double, ttl: CacheTTL, expiresIn: TimeInterval,
                                  recache: Int, five: Double, fiveResetIn: TimeInterval, seven: Double,
                                  sevenResetIn: TimeInterval, context: Int, window: Int, cost: Double,
                                  updatedIn: TimeInterval) -> SessionSnapshot {
        let now = Date()
        return SessionSnapshot.make(sessionID: String(format: "00000000-0000-0000-0000-%012d", id), name: name,
            projectDirectory: "/Users/dev/Projects/cachebar-\(id)", model: "Claude Sonnet 4.5",
            cacheHitRatio: ratio, cacheWarm: true, cacheTTL: ttl, expiresAt: now.addingTimeInterval(expiresIn),
            recacheTokensIfCold: recache, fiveHourUsage: five, fiveHourResetsAt: now.addingTimeInterval(fiveResetIn),
            sevenDayUsage: seven, sevenDayResetsAt: now.addingTimeInterval(sevenResetIn),
            contextTokens: context, contextWindowTokens: window, costUSD: cost,
            source: .statusline, updatedAt: now.addingTimeInterval(updatedIn))
    }

    private static func transcript(id: Int, directory: String, ratio: Double, ttl: CacheTTL,
                                   expiresIn: TimeInterval, context: Int, updatedIn: TimeInterval) -> SessionSnapshot {
        let now = Date()
        return SessionSnapshot.make(sessionID: String(format: "00000000-0000-0000-0000-%012d", id), name: nil,
            projectDirectory: directory, model: "Claude Sonnet 4.5",
            cacheHitRatio: ratio, cacheWarm: nil, cacheTTL: ttl, expiresAt: now.addingTimeInterval(expiresIn),
            recacheTokensIfCold: nil, fiveHourUsage: nil, fiveHourResetsAt: nil,
            sevenDayUsage: nil, sevenDayResetsAt: nil,
            contextTokens: context, contextWindowTokens: nil, costUSD: nil,
            source: .transcript, updatedAt: now.addingTimeInterval(updatedIn))
    }
}
