import Foundation

/// 界面层构造快照用的公开工厂（预览假数据、测试夹具）；与成员逐一对应，不引入额外逻辑。
extension SessionSnapshot {
    public static func make(sessionID: String, name: String? = nil, projectDirectory: String? = nil,
                            model: String? = nil, cacheHitRatio: Double? = nil, cacheWarm: Bool? = nil,
                            cacheTTL: CacheTTL? = nil, expiresAt: Date? = nil, recacheTokensIfCold: Int? = nil,
                            fiveHourUsage: Double? = nil, fiveHourResetsAt: Date? = nil,
                            sevenDayUsage: Double? = nil, sevenDayResetsAt: Date? = nil,
                            contextTokens: Int? = nil, contextWindowTokens: Int? = nil, costUSD: Double? = nil,
                            source: SnapshotSource = .statusline, updatedAt: Date = Date()) -> SessionSnapshot {
        SessionSnapshot(sessionID: sessionID, name: name, projectDirectory: projectDirectory, model: model,
                        cacheHitRatio: cacheHitRatio, cacheWarm: cacheWarm, cacheTTL: cacheTTL, expiresAt: expiresAt,
                        recacheTokensIfCold: recacheTokensIfCold, fiveHourUsage: fiveHourUsage,
                        fiveHourResetsAt: fiveHourResetsAt, sevenDayUsage: sevenDayUsage,
                        sevenDayResetsAt: sevenDayResetsAt, contextTokens: contextTokens,
                        contextWindowTokens: contextWindowTokens, costUSD: costUSD, source: source,
                        updatedAt: updatedAt)
    }
}
