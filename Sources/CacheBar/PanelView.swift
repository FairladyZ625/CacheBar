import CacheBarCore
import SwiftUI

/// 液态玻璃面板：顶部账号级额度（5h / 7d 各显示一次），每个会话一行按业主给定顺序排布，
/// 过期会话折叠到底部置灰；底部一行通知状态区。视图只消费 SessionSnapshot 与 NotificationStatus，
/// 全部格式化走 DisplayFormat。倒计时用 Timer 而非 TimelineView：本机 macOS 27.2 上 TimelineView
/// 装进窗口只渲染一帧不重绘（实测间隔 5s 两次截屏逐字节相同）。
struct PanelView: View {
    let sessions: [SessionSnapshot]
    let status: NotificationStatus
    @State private var now = Date()

    var body: some View {
        content(now: now)
            .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { now = $0 }
    }

    @ViewBuilder private func content(now: Date) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if sessions.isEmpty {
                Text("尚无可用会话数据").foregroundStyle(.secondary)
            } else {
                quotaHeader(now: now)
                Divider()
                Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 18, verticalSpacing: 10) {
                    columnHeaders
                    ForEach(sessions.filter { isActive($0, now: now) }) { session in
                        SessionRow(session: session, now: now, dimmed: false)
                    }
                    if sessions.contains(where: { !isActive($0, now: now) }) {
                        GridRow {
                            Text("已过期")
                                .font(.caption).foregroundStyle(.secondary)
                                .gridCellColumns(6)
                                .padding(.top, 4)
                        }
                        ForEach(sessions.filter { !isActive($0, now: now) }) { session in
                            SessionRow(session: session, now: now, dimmed: true)
                        }
                    }
                }
            }
            Divider()
            notificationStatusBar
        }
        .padding(18)
        .frame(width: 540, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    /// 底部状态区：通知授权三态、已排程条数、测试通知与退出；授权/排程失败的原因透传到这里。
    private var notificationStatusBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let failure = status.lastFailure {
                Text("⚠︎ \(failure)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            HStack(spacing: 14) {
                Text("通知：\(authorizationText)")
                    .font(.caption)
                    .foregroundStyle(status.authorization == .denied ? Color.red : Color.secondary)
                // 未授权或未决定（含授权请求直接报错的情形）都给出跳系统设置的出口。
                if status.authorization != .authorized {
                    Button("打开系统设置") { openNotificationSettings() }
                        .buttonStyle(.link)
                        .font(.caption)
                }
                Text("已排程 \(status.pendingCount) 条")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Button("发送测试通知") { sendTestNotification(status: status) }
                    .buttonStyle(.link)
                    .font(.caption)
                Spacer(minLength: 12)
                Button("退出 CacheBar") { NSApplication.shared.terminate(nil) }
                    .buttonStyle(.link)
                    .font(.caption)
            }
        }
    }

    private var authorizationText: String {
        switch status.authorization {
        case .authorized: return "已授权"
        case .denied: return "未授权"
        case .undetermined: return "未决定"
        }
    }

    private var columnHeaders: some View {
        GridRow {
            caption("会话").frame(width: 150, alignment: .leading)
            caption("命中率")
            caption("倒计时")
            caption("上下文")
            caption("花费")
            caption("重建 token")
        }
    }

    /// 额度是账号级：取最新快照的值在顶部各显示一次，行内不重复。
    private func quotaHeader(now: Date) -> some View {
        let freshest = sessions
            .filter { $0.fiveHourUsage != nil || $0.sevenDayUsage != nil }
            .max { $0.updatedAt < $1.updatedAt }
        return HStack(spacing: 28) {
            quota(label: "5h 额度", percent: DisplayFormat.usagePercent(freshest?.fiveHourUsage),
                  resetsAt: freshest?.fiveHourResetsAt, now: now)
            quota(label: "7d 额度", percent: DisplayFormat.usagePercent(freshest?.sevenDayUsage),
                  resetsAt: freshest?.sevenDayResetsAt, now: now)
        }
    }

    private func quota(label: String, percent: String?, resetsAt: Date?, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(percent ?? "—").font(.system(.body, weight: .semibold))
                if let reset = DisplayFormat.resetCountdown(resetsAt: resetsAt, now: now) {
                    Text("\(reset) 后重置").font(.caption).foregroundStyle(.secondary)
                }
            }
            .monospacedDigit()
        }
    }

    private func caption(_ text: String) -> some View {
        Text(text).font(.caption).foregroundStyle(.secondary)
    }

    /// 与 SessionStore 的排序口径一致：无过期时刻的会话不算过期。
    private func isActive(_ session: SessionSnapshot, now: Date) -> Bool {
        session.expiresAt.map { $0 >= now } ?? true
    }
}

private struct SessionRow: View {
    let session: SessionSnapshot
    let now: Date
    let dimmed: Bool

    var body: some View {
        GridRow {
            Text(displayName)
                .font(.system(.body, weight: .medium))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: 150, alignment: .leading)
                .help(session.projectDirectory ?? session.sessionID)
            value(DisplayFormat.hitRatioPercent(session.cacheHitRatio))
            Text(DisplayFormat.cacheCountdown(expiresAt: session.expiresAt, now: now) ?? "—")
                .monospacedDigit()
                .foregroundStyle(Urgency.color(expiresAt: session.expiresAt, now: now))
            value(DisplayFormat.tokenCount(session.contextTokens))
            value(DisplayFormat.usd(session.costUSD))
            value(DisplayFormat.tokenCount(session.recacheTokensIfCold ?? session.contextTokens))
        }
        .opacity(dimmed ? 0.45 : 1)
    }

    private var displayName: String {
        if let name = session.name, !name.isEmpty { return name }
        if let directory = session.projectDirectory, !directory.isEmpty {
            return (directory as NSString).lastPathComponent
        }
        return session.sessionID
    }

    private func value(_ text: String?) -> some View {
        Text(text ?? "—").monospacedDigit()
    }
}

/// 临近过期的配色，菜单栏标题与面板行共用；阈值与通知（10 分钟 / 2 分钟）对齐。
enum Urgency {
    static func color(expiresAt: Date?, now: Date) -> Color {
        guard let expiresAt else { return .primary }
        let seconds = expiresAt.timeIntervalSince(now)
        if seconds <= 120 { return .red }
        if seconds <= 600 { return .orange }
        return .primary
    }
}
