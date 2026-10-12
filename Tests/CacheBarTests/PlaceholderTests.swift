import CacheBarCore
import Testing

@Test("占位内容非空：菜单栏标题与至少一行面板文本")
func placeholderContentIsNonEmpty() {
    #expect(!Placeholder.menuBarTitle.isEmpty)
    #expect(!Placeholder.panelLines.isEmpty)
    #expect(Placeholder.panelLines.allSatisfy { !$0.isEmpty })
}
