import CacheBarCore
import SwiftUI

/// 菜单栏标题：最紧急会话的「命中率 · 缓存倒计时」，每秒重算，临近过期变色。
/// 用 Timer 而非 TimelineView：本机 macOS 27.2 上 TimelineView 装进 MenuBarExtra label
/// 会触发 SwiftUI updateButton 的立即重排死循环（sample 实测主线程 100% 自旋）。
public struct MenuTitleView: View {
    public let sessions: [SessionSnapshot]
    @State private var now = Date()

    public init(sessions: [SessionSnapshot]) {
        self.sessions = sessions
    }

    public var body: some View {
        title(at: now)
            .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { now = $0 }
    }

    @ViewBuilder private func title(at now: Date) -> some View {
        if let session = sessions.first, let text = MenuTitle.text(for: session, now: now) {
            Text(text)
                .monospacedDigit()
                .foregroundStyle(Urgency.color(expiresAt: session.expiresAt, now: now))
        } else {
            Text("⏳ --:--").monospacedDigit()
        }
    }
}

/// 标题文案；sessions 由 SessionStore 按「未过期且最早过期优先」排好，first 即最紧急。
private enum MenuTitle {
    static func text(for session: SessionSnapshot, now: Date) -> String? {
        guard let countdown = DisplayFormat.cacheCountdown(expiresAt: session.expiresAt, now: now) else { return nil }
        return "\(DisplayFormat.hitRatioPercent(session.cacheHitRatio) ?? "—") · \(countdown)"
    }
}
