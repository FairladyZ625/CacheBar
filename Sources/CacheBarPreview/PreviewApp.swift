import CacheBarUI
import SwiftUI

/// 仅开发用的面板渲染器：普通窗口 + 假数据渲染与产品同一份 PanelView，供 shell 侧
/// screencapture 截图。用法：CacheBarPreview --scheme light|dark
/// 窗口号打到 stdout（CACHEBAR_PREVIEW_WINDOW=<id>），由外部截图与终止；本进程不自己
/// 调 screencapture——新二进制没有屏幕录制授权，应用内截图会卡 TCC 弹窗（实测）。
@main
struct CacheBarPreviewApp: App {
    @State private var scheme: ColorScheme = .light

    init() {
        // 注意：init 里直接给 @State 属性赋值会被 SwiftUI 丢弃（实测 PARSED=light），
        // 必须走 _scheme = State(initialValue:) 才进得了首帧。
        var parsed: ColorScheme = .light
        let args = CommandLine.arguments
        if let index = args.firstIndex(of: "--scheme"), index + 1 < args.count {
            parsed = args[index + 1] == "dark" ? .dark : .light
        }
        _scheme = State(initialValue: parsed)
    }

    var body: some Scene {
        WindowGroup {
            PreviewSurface(scheme: scheme)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}

private struct PreviewSurface: View {
    let scheme: ColorScheme

    var body: some View {
        ZStack {
            backdrop
            PanelView(sessions: PreviewSessions.samples, status: .preview)
        }
        .frame(width: 760, height: 980)
        // 本机对 WindowGroup 窗口实测：preferredColorScheme / NSApp.appearance / NSWindow.appearance
        // 三者都切不动 SwiftUI 的外观渲染，只能直接注入 colorScheme 环境值。
        .environment(\.colorScheme, scheme)
        .background(WindowConfigurator(appearanceName: scheme == .dark ? .darkAqua : .aqua))
    }

    /// 类壁纸背景：液态玻璃要有可折射的内容，纯色背景看不出玻璃质感。
    private var backdrop: some View {
        ZStack {
            LinearGradient(colors: [.cyan, .indigo, .pink], startPoint: .top, endPoint: .bottom)
            Circle().fill(.orange.opacity(0.55)).blur(radius: 60).frame(width: 260).offset(x: 150, y: -220)
            Circle().fill(.teal.opacity(0.6)).blur(radius: 60).frame(width: 320).offset(x: -170, y: 260)
            Circle().fill(.white.opacity(0.3)).blur(radius: 40).frame(width: 180).offset(x: -80, y: -260)
        }
        .ignoresSafeArea()
    }
}

/// 把所在窗口的外观设成指定 appearance 并把 windowNumber 打到 stdout 供 shell 截图。
private struct WindowConfigurator: NSViewRepresentable {
    let appearanceName: NSAppearance.Name
    @MainActor private static var lastReported = 0

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { self.configure(view.window) }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async { self.configure(view.window) }
    }

    @MainActor private func configure(_ window: NSWindow?) {
        guard let window else { return }
        window.appearance = NSAppearance(named: appearanceName)
        let number = window.windowNumber
        guard number != 0, number != Self.lastReported else { return }
        Self.lastReported = number
        print("CACHEBAR_PREVIEW_WINDOW=\(number)")
        fflush(stdout)
    }
}
