import CacheBarCore
import SwiftUI

/// 液态玻璃面板：外层一整块玻璃做面板本体，额度区与每个活跃会话行是玻璃上的独立玻璃元素
/// （GlassEffectContainer 让相邻玻璃互相折射融合），按钮走 .buttonStyle(.glass)。
/// 视图只消费 SessionSnapshot 与 NotificationStatus，比例算 BarMath、文案走 DisplayFormat。
/// 倒计时用 Timer 而非 TimelineView：本机 macOS 27.2 上 TimelineView 装进窗口只渲染一帧不重绘。
public struct PanelView: View {
    public let sessions: [SessionSnapshot]
    public let status: NotificationStatus
    @State private var now = Date()
    @State private var expiredExpanded = false

    public init(sessions: [SessionSnapshot], status: NotificationStatus) {
        self.sessions = sessions
        self.status = status
    }

    public var body: some View {
        content(now: now)
            .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { now = $0 }
    }

    private func content(now: Date) -> some View {
        let active = sessions.filter { isActive($0, now: now) }
        let expired = sessions.filter { !isActive($0, now: now) }
        return GlassEffectContainer(spacing: 10) {
            VStack(alignment: .leading, spacing: 10) {
                if sessions.isEmpty {
                    Text("尚无可用会话数据").font(.body).foregroundStyle(.secondary)
                } else {
                    quotaHeader(now: now)
                    ForEach(active) { session in
                        SessionCard(session: session, now: now)
                    }
                    if !expired.isEmpty {
                        expiredToggle(count: expired.count)
                        if expiredExpanded {
                            ForEach(expired) { session in
                                SessionCard(session: session, now: now, dimmed: true)
                            }
                        }
                    }
                }
                notificationStatusBar
            }
        }
        .padding(20)
        .frame(width: 640, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    /// 底部状态区：通知授权三态、已排程条数、测试通知与退出；授权/排程失败的原因透传到这里。
    private var notificationStatusBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let failure = status.lastFailure {
                Text("⚠︎ \(failure)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            HStack(spacing: 12) {
                Text("通知：\(authorizationText)")
                    .font(.callout)
                    .foregroundStyle(status.authorization == .denied ? Color.red : Color.secondary)
                // 未授权或未决定（含授权请求直接报错的情形）都给出跳系统设置的出口。
                if status.authorization != .authorized {
                    glassButton("打开系统设置") { openNotificationSettings() }
                }
                Text("已排程 \(status.pendingCount) 条")
                    .font(.callout)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Spacer(minLength: 12)
                glassButton("发送测试通知") { sendTestNotification(status: status) }
                glassButton("退出 CacheBar") { NSApplication.shared.terminate(nil) }
            }
        }
    }

    private func glassButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.glass)
            .font(.callout)
    }

    private var authorizationText: String {
        switch status.authorization {
        case .authorized: return "已授权"
        case .denied: return "未授权"
        case .undetermined: return "未决定"
        }
    }

    /// 额度是账号级：取最新快照的值在顶部各显示一次，行内不重复。
    private func quotaHeader(now: Date) -> some View {
        let freshest = sessions
            .filter { $0.fiveHourUsage != nil || $0.sevenDayUsage != nil }
            .max { $0.updatedAt < $1.updatedAt }
        return HStack(spacing: 28) {
            quotaGauge(label: "5h 额度", usedPercent: freshest?.fiveHourUsage,
                       resetsAt: freshest?.fiveHourResetsAt, now: now)
            quotaGauge(label: "7d 额度", usedPercent: freshest?.sevenDayUsage,
                       resetsAt: freshest?.sevenDayResetsAt, now: now)
        }
        .padding(EdgeInsets(top: 12, leading: 16, bottom: 14, trailing: 16))
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func quotaGauge(label: String, usedPercent: Double?, resetsAt: Date?, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).font(.callout).foregroundStyle(.secondary)
            HStack(spacing: 10) {
                Text(DisplayFormat.usagePercent(usedPercent) ?? "—")
                    .font(.system(.title3, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Urgency.quotaColor(usedPercent))
                if let fill = BarMath.quotaFill(usedPercent: usedPercent) {
                    GaugeBar(fraction: fill, height: 9, color: Urgency.quotaColor(usedPercent))
                }
                if let reset = DisplayFormat.resetCountdown(resetsAt: resetsAt, now: now) {
                    Text("\(reset) 后重置").font(.callout).foregroundStyle(.secondary).monospacedDigit()
                }
            }
        }
    }

    /// 已过期默认折叠成一行；过期会话对决策无价值，但保留点击展开的追溯出口。
    private func expiredToggle(count: Int) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.2)) { expiredExpanded.toggle() }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: expiredExpanded ? "chevron.down" : "chevron.right")
                Text("已过期 \(count) 个")
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.glass)
        .font(.callout)
        .foregroundStyle(.secondary)
    }

    /// 与 SessionStore 的排序口径一致：无过期时刻的会话不算过期。
    private func isActive(_ session: SessionSnapshot, now: Date) -> Bool {
        session.expiresAt.map { $0 >= now } ?? true
    }
}

/// 单个会话卡：名字与倒计时大字，剩余寿命条是整卡的视觉重心；上下文细条与命中/花费是次级信息。
private struct SessionCard: View {
    let session: SessionSnapshot
    let now: Date
    var dimmed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(displayName)
                    .font(.system(.title3, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .help(session.projectDirectory ?? session.sessionID)
                Spacer(minLength: 12)
                Text("命中 \(DisplayFormat.hitRatioPercent(session.cacheHitRatio) ?? "—")")
                    .font(.callout)
                    .monospacedDigit()
                    .foregroundStyle(Urgency.hitRatioColor(session.cacheHitRatio))
                Text(DisplayFormat.usd(session.costUSD) ?? "—")
                    .font(.callout)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 10) {
                Text(DisplayFormat.cacheCountdown(expiresAt: session.expiresAt, now: now) ?? "—")
                    .font(.system(.title3, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(Urgency.color(expiresAt: session.expiresAt, now: now))
                    .frame(width: 96, alignment: .leading)
                if let fill = BarMath.lifetimeFill(expiresAt: session.expiresAt, ttl: session.cacheTTL, now: now) {
                    GaugeBar(fraction: fill, height: 12, color: Urgency.color(expiresAt: session.expiresAt, now: now))
                }
                if let ttl = session.cacheTTL {
                    Text(ttl.rawValue).font(.caption).monospacedDigit().foregroundStyle(.secondary)
                }
            }
            contextRow
        }
        .padding(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
        .opacity(dimmed ? 0.5 : 1)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    /// 上下文细条：窗口大小未知（transcript 兜底会话）不画条只显示数字；重建 token 是缓存冷启的代价参考。
    private var contextRow: some View {
        HStack(spacing: 10) {
            Text("上下文").font(.callout).foregroundStyle(.secondary)
            if let fill = BarMath.contextFill(contextTokens: session.contextTokens,
                                              contextWindowTokens: session.contextWindowTokens) {
                GaugeBar(fraction: fill, height: 5)
            }
            Text(contextText).font(.callout).monospacedDigit().foregroundStyle(.secondary)
            Text("重建 \(DisplayFormat.tokenCount(session.recacheTokensIfCold ?? session.contextTokens) ?? "—")")
                .font(.callout)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }

    private var contextText: String {
        let used = DisplayFormat.tokenCount(session.contextTokens) ?? "—"
        guard let window = DisplayFormat.tokenCount(session.contextWindowTokens) else { return used }
        return "\(used) / \(window)"
    }

    private var displayName: String {
        if let name = session.name, !name.isEmpty { return name }
        if let directory = session.projectDirectory, !directory.isEmpty {
            return (directory as NSString).lastPathComponent
        }
        return session.sessionID
    }
}

/// 量条：胶囊轨道 + 按比例填充；fraction 为 nil 时整条不出现（调用方决定不画）。
struct GaugeBar: View {
    let fraction: Double?
    var height: CGFloat = 8
    var color: Color = .accentColor

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.primary.opacity(0.14))
                if let fraction {
                    Capsule().fill(color).frame(width: geo.size.width * fraction)
                }
            }
        }
        .frame(height: height)
    }
}

/// 临近与超额的配色，菜单栏标题、面板行与量条共用；阈值与通知（10 分钟 / 2 分钟）对齐。
enum Urgency {
    static func color(expiresAt: Date?, now: Date) -> Color {
        guard let expiresAt else { return .primary }
        let seconds = expiresAt.timeIntervalSince(now)
        if seconds <= 120 { return .red }
        if seconds <= 600 { return .orange }
        return .primary
    }

    /// 额度条配色：80% 起橙、95% 起红，其余系统强调色。
    static func quotaColor(_ usedPercent: Double?) -> Color {
        guard let usedPercent else { return .accentColor }
        if usedPercent >= 95 { return .red }
        if usedPercent >= 80 { return .orange }
        return .accentColor
    }

    /// 命中率配色：低于 50% 是异常信号，标橙；取不到时用次级灰。
    static func hitRatioColor(_ ratio: Double?) -> Color {
        guard let ratio else { return .secondary }
        return ratio < 0.5 ? .orange : .secondary
    }
}
