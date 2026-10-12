import CacheBarCore
import CacheBarUI
import SwiftUI
import UserNotifications

@main
struct CacheBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store = SessionStore()
    @State private var notificationStatus = NotificationStatus()
    private let preview = PreviewMode.current

    init() {
        // 预览暗色走 NSApp.appearance：本机上 preferredColorScheme 对窗口外观不生效（截图实测）。
        if let scheme = PreviewMode.current.colorScheme {
            NSApplication.shared.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
        }
    }

    var body: some Scene {
        menuBarExtra
    }

    private var menuBarExtra: some Scene {
        MenuBarExtra(isInserted: .constant(true)) {
            Group {
                if preview.isActive {
                    PanelView(sessions: preview.sessions, status: .preview)
                } else {
                    PanelView(sessions: store.sessions, status: notificationStatus)
                        // 面板每次打开时同步授权显示：用户可能刚在系统设置里改过，只读现状不弹窗。
                        .task { await refreshAuthorizationDisplay(status: notificationStatus) }
                }
            }
            // MenuBarExtra(.window) 的窗口自带一套材质背景，叠在内容的 glassEffect 之下就成了
            // 双层毛玻璃；窗口背景清透明后只留内容那一层玻璃（真实观感由业主在面板上亲验）。
            .background(PanelWindowMaterialRemover())
        } label: {
            MenuTitleView(sessions: preview.isActive ? preview.sessions : store.sessions)
                .task {
                    if !preview.isActive {
                        store.start()
                        attachNotifications(to: store, status: notificationStatus)
                    }
                }
        }
        .menuBarExtraStyle(.window)
    }
}

/// 把面板所在窗口的背景清成透明。makeNSView 时窗口可能尚未挂上，用主队列异步补一次；
/// updateNSView 在窗口复用/重开时再断言一遍，属性设置幂等。
private struct PanelWindowMaterialRemover: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { Self.clearBackground(of: view.window) }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        Self.clearBackground(of: view.window)
    }

    private static func clearBackground(of window: NSWindow?) {
        window?.isOpaque = false
        window?.backgroundColor = .clear
    }
}

/// 应用级不变量集中在这里：窗口（含菜单栏面板）关闭不退出，退出只走面板上的退出按钮；
/// 通知 delegate 在启动完成时挂上，保证前台 willPresent 生效。
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let notificationPresenter = NotificationPresenter()

    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = notificationPresenter
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
