import CacheBarCore
import SwiftUI

@main
struct CacheBarApp: App {
    @State private var store = SessionStore()

    var body: some Scene {
        MenuBarExtra(menuTitle, systemImage: "hourglass") {
            PanelView(sessions: store.sessions)
                .task { store.start() }
        }
        .menuBarExtraStyle(.window)
    }
}

private extension CacheBarApp {
    var menuTitle: String {
        guard let expiry = store.sessions.first?.expiresAt else { return "⏳ --:--" }
        let seconds = max(0, Int(expiry.timeIntervalSinceNow))
        return String(format: "⏳ %02d:%02d", seconds / 3600, (seconds % 3600) / 60)
    }
}

struct PanelView: View {
    let sessions: [SessionSnapshot]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if sessions.isEmpty {
                Text("尚无可用会话数据")
            }
            ForEach(sessions) { session in
                VStack(alignment: .leading, spacing: 3) {
                    Text(session.name ?? session.sessionID).font(.headline)
                    TimelineView(.periodic(from: .now, by: 30)) { timeline in
                        Text(session.expiresAt.map { expiry in
                            let seconds = max(0, Int(expiry.timeIntervalSince(timeline.date)))
                            return String(format: "缓存倒计时 %02d:%02d:%02d", seconds / 3600, (seconds % 3600) / 60, seconds % 60)
                        } ?? "缓存时间未知")
                        .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(14)
        .frame(minWidth: 280)
    }
}
