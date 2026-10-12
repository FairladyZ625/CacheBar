import CacheBarCore
import SwiftUI

@main
struct CacheBarApp: App {
    var body: some Scene {
        MenuBarExtra(Placeholder.menuBarTitle, systemImage: "hourglass") {
            PanelView(lines: Placeholder.panelLines)
        }
        .menuBarExtraStyle(.window)
    }
}

struct PanelView: View {
    let lines: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(lines, id: \.self) { line in
                Text(line)
            }
        }
        .padding(14)
        .frame(minWidth: 280)
    }
}
