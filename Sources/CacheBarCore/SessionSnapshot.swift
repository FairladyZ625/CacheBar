import Foundation

public enum CacheTTL: String, Codable, Sendable { case oneHour = "1h", fiveMinutes = "5m" }
public enum SnapshotSource: String, Codable, Sendable { case statusline, transcript }

public struct SessionSnapshot: Identifiable, Equatable, Sendable {
    public var id: String { sessionID }
    public let sessionID: String
    public var name: String?
    public var projectDirectory: String?
    public var model: String?
    public var cacheHitRatio: Double?
    public var cacheWarm: Bool?
    public var cacheTTL: CacheTTL?
    public var expiresAt: Date?
    public var recacheTokensIfCold: Int?
    public var fiveHourUsage: Double?
    public var fiveHourResetsAt: Date?
    public var sevenDayUsage: Double?
    public var sevenDayResetsAt: Date?
    public var contextTokens: Int?
    public var contextWindowTokens: Int?
    public var costUSD: Double?
    public var source: SnapshotSource
    public var updatedAt: Date

    public static func merged(statusline: SessionSnapshot?, transcript: SessionSnapshot?) -> SessionSnapshot? {
        guard let primary = statusline else { return transcript }
        guard let fallback = transcript else { return primary }
        var result = fallback.updatedAt > primary.updatedAt ? fallback : primary
        result.name = primary.name ?? fallback.name
        result.projectDirectory = primary.projectDirectory ?? fallback.projectDirectory
        result.model = primary.model ?? fallback.model
        result.fiveHourUsage = primary.fiveHourUsage
        result.fiveHourResetsAt = primary.fiveHourResetsAt
        result.sevenDayUsage = primary.sevenDayUsage
        result.sevenDayResetsAt = primary.sevenDayResetsAt
        result.costUSD = primary.costUSD
        return result
    }
}

public protocol AgentAdapter {
    func snapshot(fromStatusline data: Data, now: Date?) throws -> SessionSnapshot
    func snapshots(fromTranscript data: Data) throws -> [SessionSnapshot]
}

public struct ClaudeCodeAdapter: AgentAdapter, Sendable {
    private let clock: @Sendable () -> Date
    public init(now: @escaping @Sendable () -> Date = Date.init) { clock = now }

    public func snapshot(fromStatusline data: Data, now: Date? = nil) throws -> SessionSnapshot {
        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        let context = root["context_window"] as? [String: Any] ?? [:]
        let usage = context["current_usage"] as? [String: Any] ?? [:]
        let cacheRead = number(usage["cache_read_input_tokens"])
        let cacheCreate = number(usage["cache_creation_input_tokens"])
        let input = number(usage["input_tokens"])
        let total = cacheRead + cacheCreate + input
        let cache = root["prompt_cache"] as? [String: Any] ?? [:]
        let limits = root["rate_limits"] as? [String: Any] ?? [:]
        let five = limits["five_hour"] as? [String: Any] ?? [:]
        let seven = limits["seven_day"] as? [String: Any] ?? [:]
        let cost = root["cost"] as? [String: Any] ?? [:]
        let model = root["model"] as? [String: Any] ?? [:]
        let timestamp = now ?? clock()
        return SessionSnapshot(sessionID: root["session_id"] as? String ?? "", name: root["session_name"] as? String, projectDirectory: root["cwd"] as? String, model: model["display_name"] as? String,
            cacheHitRatio: total > 0 ? Double(cacheRead) / Double(total) : nil, cacheWarm: cache["warm"] as? Bool,
            cacheTTL: (cache["ttl"] as? String).flatMap(CacheTTL.init(rawValue:)), expiresAt: date(cache["expires_at"]),
            recacheTokensIfCold: optionalNumber(cache["recache_tokens_if_cold"]), fiveHourUsage: five["used_percentage"] as? Double,
            fiveHourResetsAt: date(five["resets_at"]), sevenDayUsage: seven["used_percentage"] as? Double,
            sevenDayResetsAt: date(seven["resets_at"]), contextTokens: optionalNumber(context["total_input_tokens"]),
            contextWindowTokens: optionalNumber(context["context_window_size"]), costUSD: cost["total_cost_usd"] as? Double,
            source: .statusline, updatedAt: timestamp)
    }

    public func snapshots(fromTranscript data: Data) throws -> [SessionSnapshot] {
        let text = String(decoding: data, as: UTF8.self)
        var latest: [String: SessionSnapshot] = [:]
        var ttlBySession: [String: CacheTTL] = [:]
        var seen = Set<String>()
        for line in text.split(separator: "\n").dropLast(text.hasSuffix("\n") ? 0 : 1) {
            guard let rowData = String(line).data(using: .utf8),
                  let row = try? JSONSerialization.jsonObject(with: rowData) as? [String: Any],
                  row["type"] as? String == "assistant", row["isSidechain"] as? Bool != true,
                  let sessionID = row["sessionId"] as? String,
                  let requestID = row["requestId"] as? String,
                  let message = row["message"] as? [String: Any],
                  let usage = message["usage"] as? [String: Any] else { continue }
            let cacheCreation = usage["cache_creation"] as? [String: Any] ?? [:]
            if number(cacheCreation["ephemeral_1h_input_tokens"]) > 0 { ttlBySession[sessionID] = .oneHour }
            if number(cacheCreation["ephemeral_5m_input_tokens"]) > 0 { ttlBySession[sessionID] = .fiveMinutes }
            let key = sessionID + ":" + requestID
            guard seen.insert(key).inserted else { continue }
            let read = number(usage["cache_read_input_tokens"])
            let create = number(usage["cache_creation_input_tokens"])
            let input = number(usage["input_tokens"])
            let total = read + create + input
            let time = parseDate(row["timestamp"]) ?? .distantPast
            let ttl = ttlBySession[sessionID]
            latest[sessionID] = SessionSnapshot(sessionID: sessionID, name: nil, projectDirectory: row["cwd"] as? String, model: message["model"] as? String,
                cacheHitRatio: total > 0 ? Double(read) / Double(total) : nil, cacheWarm: nil, cacheTTL: ttl,
                expiresAt: ttl.map { time.addingTimeInterval($0 == .oneHour ? 3600 : 300) }, recacheTokensIfCold: nil,
                fiveHourUsage: nil, fiveHourResetsAt: nil, sevenDayUsage: nil, sevenDayResetsAt: nil,
                contextTokens: total, contextWindowTokens: nil, costUSD: nil, source: .transcript, updatedAt: time)
        }
        return Array(latest.values)
    }
}

private func number(_ value: Any?) -> Int { (value as? NSNumber)?.intValue ?? 0 }
private func optionalNumber(_ value: Any?) -> Int? { (value as? NSNumber)?.intValue }
private func date(_ value: Any?) -> Date? { (value as? NSNumber).map { Date(timeIntervalSince1970: $0.doubleValue) } }
private func parseDate(_ value: Any?) -> Date? {
    guard let value = value as? String else { return nil }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.date(from: value) ?? ISO8601DateFormatter().date(from: value)
}
