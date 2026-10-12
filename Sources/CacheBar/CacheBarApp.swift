import CacheBarCore
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
                    PanelView(sessions: preview.sessions, status: Self.previewStatus)
                } else {
                    PanelView(sessions: store.sessions, status: notificationStatus)
                        // 面板每次打开时同步授权显示：用户可能刚在系统设置里改过，只读现状不弹窗。
                        .task { await refreshAuthorizationDisplay(status: notificationStatus) }
                }
            }
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

    private static let previewStatus: NotificationStatus = {
        let status = NotificationStatus()
        status.setAuthorization(.authorized)
        status.setPendingCount(4)
        return status
    }()
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
