import CacheBarCore
import SwiftUI

@main
struct CacheBarApp: App {
    @State private var store = SessionStore()
    private let preview = PreviewMode.current

    init() {
        // 预览暗色走 NSApp.appearance：本机上 preferredColorScheme 对窗口外观不生效（截图实测）。
        if let scheme = PreviewMode.current.colorScheme {
            NSApplication.shared.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
        }
    }

    var body: some Scene {
        menuBarExtra
        previewWindow
    }

    private var menuBarExtra: some Scene {
        MenuBarExtra(isInserted: .constant(true)) {
            Group {
                if preview.isActive {
                    PanelView(sessions: preview.sessions)
                } else {
                    PanelView(sessions: store.sessions)
                }
            }
        } label: {
            MenuTitleView(sessions: preview.isActive ? preview.sessions : store.sessions)
                .task {
                    if !preview.isActive {
                        store.start()
                        attachNotifications(to: store)
                    }
                }
        }
        .menuBarExtraStyle(.window)
    }

    /// 仅调试用：CACHEBAR_PREVIEW_WINDOW=1 时把同一份面板放进普通窗口，
    /// 供截图与布局联调（SDK 无程序化打开 MenuBarExtra 面板的 API）。
    /// SceneBuilder 不支持条件分支，窗口常驻声明、靠启动行为控制是否出现。
    private var previewWindow: some Scene {
        Window("CacheBar 预览", id: PreviewMode.windowID) {
            PanelView(sessions: preview.sessions)
                .onAppear { NSApplication.shared.activate(ignoringOtherApps: true) }
        }
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(preview.showsWindow ? .presented : .suppressed)
    }
}
