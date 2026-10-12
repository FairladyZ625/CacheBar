import Foundation

/// 展示用纯格式化：数值 → 定宽友好的短字符串。取不到的值返回 nil，占位符由视图决定。
public enum DisplayFormat {
    /// 本轮缓存命中率（0...1 比例，由适配器按 read/total 算出）→ "92%"。
    public static func hitRatioPercent(_ ratio: Double?) -> String? {
        ratio.map { "\(Int(($0 * 100).rounded()))%" }
    }

    /// 账号级额度百分比（0...100 标度，statusline 的 used_percentage）→ "62%"。
    public static func usagePercent(_ percent: Double?) -> String? {
        percent.map { "\(Int($0.rounded()))%" }
    }

    /// 缓存过期倒计时 → 每秒走的 "41:32" / "1:02:11"；过期 → "已过期"；无过期时刻 → nil。
    public static func cacheCountdown(expiresAt: Date?, now: Date) -> String? {
        guard let expiresAt else { return nil }
        let seconds = Int(expiresAt.timeIntervalSince(now).rounded())
        guard seconds > 0 else { return "已过期" }
        return clockString(seconds: seconds)
    }

    /// 额度重置倒计时 → 紧凑的 "43s" / "47m" / "2h15m" / "3d4h"；无重置时刻 → nil。
    public static func resetCountdown(resetsAt: Date?, now: Date) -> String? {
        guard let resetsAt else { return nil }
        let seconds = max(0, Int(resetsAt.timeIntervalSince(now).rounded()))
        return shortDuration(seconds: seconds)
    }

    /// 上下文 / 重建 token 数 → "842" / "148.3k" / "1.2M"。
    public static func tokenCount(_ tokens: Int?) -> String? {
        guard let tokens else { return nil }
        if tokens < 1_000 { return "\(tokens)" }
        if tokens < 1_000_000 { return compact(tokens, divisor: 1_000, suffix: "k") }
        return compact(tokens, divisor: 1_000_000, suffix: "M")
    }

    /// 本次会话花费 → 小于 $1 保留到千分位 "$0.482"，否则 "$4.21"。
    public static func usd(_ amount: Double?) -> String? {
        guard let amount else { return nil }
        if abs(amount) < 1 {
            return "$" + String(format: "%.4f", amount).replacingOccurrences(of: #"\.?[0]+$"#, with: "", options: .regularExpression)
        }
        return String(format: "$%.2f", amount)
    }

    /// 秒数 → "41:32"；满一小时 → "1:02:11"。
    static func clockString(seconds: Int) -> String {
        let hours = seconds / 3600, minutes = seconds % 3600 / 60, sec = seconds % 60
        if hours > 0 { return String(format: "%d:%02d:%02d", hours, minutes, sec) }
        return String(format: "%02d:%02d", minutes, sec)
    }

    /// 秒数 → "43s" / "47m" / "2h15m" / "3d4h"，零分量省略。
    static func shortDuration(seconds: Int) -> String {
        let days = seconds / 86_400, hours = seconds % 86_400 / 3600, minutes = seconds % 3600 / 60
        if days > 0 { return hours > 0 ? "\(days)d\(hours)h" : "\(days)d" }
        if hours > 0 { return minutes > 0 ? "\(hours)h\(minutes)m" : "\(hours)h" }
        if minutes > 0 { return "\(minutes)m" }
        return "\(seconds)s"
    }

    private static func compact(_ value: Int, divisor: Int, suffix: String) -> String {
        let scaled = Double(value) / Double(divisor)
        let text = String(format: "%.1f", scaled).replacingOccurrences(of: #"\.0$"#, with: "", options: .regularExpression)
        return text + suffix
    }
}
