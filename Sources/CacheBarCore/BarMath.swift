import Foundation

/// 量条填充比例的纯计算：视图只负责画。结果一律钳制在 0...1；取不到数据返回 nil（不画条，只显示数字）。
public enum BarMath {
    /// 额度条：已用百分比（statusline 的 0...100 标度）→ 填充比例。
    public static func quotaFill(usedPercent: Double?) -> Double? {
        guard let usedPercent else { return nil }
        return clamped(usedPercent / 100)
    }

    /// 剩余寿命条：剩余时间 / TTL。5m 档按 300 秒，1h 与档位未知按 3600 秒；已过期填满为 0；无过期时刻不画条。
    public static func lifetimeFill(expiresAt: Date?, ttl: CacheTTL?, now: Date) -> Double? {
        guard let expiresAt else { return nil }
        let span: TimeInterval = ttl == .fiveMinutes ? 300 : 3600
        return clamped(expiresAt.timeIntervalSince(now) / span)
    }

    /// 上下文条：context / window。窗口大小未知（transcript 兜底会话）不画条，只显示数字。
    public static func contextFill(contextTokens: Int?, contextWindowTokens: Int?) -> Double? {
        guard let contextTokens, let contextWindowTokens, contextWindowTokens > 0 else { return nil }
        return clamped(Double(contextTokens) / Double(contextWindowTokens))
    }

    private static func clamped(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}
