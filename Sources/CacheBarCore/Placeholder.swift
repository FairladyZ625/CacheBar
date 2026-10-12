/// T2 骨架的占位内容。视图只消费 CacheBarCore 暴露的数据；
/// T3 的适配器与 SessionStore 就位后由真实会话快照取代本类型。
public enum Placeholder {
    /// 菜单栏标题的占位倒计时。
    public static let menuBarTitle = "⏳ --:--"

    /// 面板的占位行。
    public static let panelLines = [
        "CacheBar 骨架已就绪",
        "会话指标由 T3 适配器接入",
    ]
}
