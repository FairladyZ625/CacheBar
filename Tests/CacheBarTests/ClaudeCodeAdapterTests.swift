import Foundation
import Testing
@testable import CacheBarCore

@Test("statusline decodes current-turn ratio, expiry, limits and cost")
func statuslineSnapshot() throws {
    let data = try Data(contentsOf: fixture("statusline.json"))
    let snapshot = try ClaudeCodeAdapter().snapshot(fromStatusline: data, now: Date(timeIntervalSince1970: 1_791_778_800))
    #expect(snapshot.sessionID == "fixture-session")
    #expect(snapshot.cacheHitRatio == 0.5)
    #expect(snapshot.expiresAt == Date(timeIntervalSince1970: 1_791_778_836))
    #expect(snapshot.cacheTTL == .oneHour)
    #expect(snapshot.fiveHourUsage == 47)
    #expect(snapshot.costUSD == 789.3)
    #expect(snapshot.contextTokens == 270_622)
}

@Test("transcript ignores sidechains, deduplicates requests and accepts read-only cache touches")
func transcriptFallback() throws {
    let data = try Data(contentsOf: fixture("transcript.jsonl"))
    let snapshots = try ClaudeCodeAdapter(now: { Date(timeIntervalSince1970: 1_800) }).snapshots(fromTranscript: data)
    #expect(snapshots.count == 2)
    let snapshot = try #require(snapshots.first { $0.sessionID == "fixture-session" })
    #expect(snapshot.cacheHitRatio == 0.8)
    #expect(snapshot.cacheTTL == .fiveMinutes)
    #expect(snapshot.expiresAt == Date(timeIntervalSince1970: 2_100))
    #expect(snapshot.contextTokens == 150)
    #expect(snapshot.costUSD == nil)
    let hourSnapshot = try #require(snapshots.first { $0.sessionID == "fixture-one-hour" })
    #expect(hourSnapshot.cacheTTL == .oneHour)
    #expect(hourSnapshot.expiresAt == Date(timeIntervalSince1970: 6_000))
}

@Test("statusline and transcript merge keeps newer cache fields and snapshot-only metrics")
func mergesSources() throws {
    var primary = try ClaudeCodeAdapter().snapshot(fromStatusline: Data(contentsOf: fixture("statusline.json")), now: .distantPast)
    primary.updatedAt = Date(timeIntervalSince1970: 10)
    let fallback = SessionSnapshot(sessionID: primary.sessionID, name: nil, projectDirectory: nil, model: nil, cacheHitRatio: 0.4, cacheWarm: true, cacheTTL: .fiveMinutes, expiresAt: Date(timeIntervalSince1970: 20), recacheTokensIfCold: nil, fiveHourUsage: nil, fiveHourResetsAt: nil, sevenDayUsage: nil, sevenDayResetsAt: nil, contextTokens: 5, contextWindowTokens: nil, costUSD: nil, source: .transcript, updatedAt: Date(timeIntervalSince1970: 30))
    let result = SessionSnapshot.merged(statusline: primary, transcript: fallback)
    #expect(result?.cacheHitRatio == 0.4)
    #expect(result?.costUSD == 789.3)
    #expect(result?.fiveHourUsage == 47)
}

@Test("missing optional statusline fields stay nil")
func missingFieldsAreNil() throws {
    let snapshot = try ClaudeCodeAdapter().snapshot(fromStatusline: Data("{\"session_id\":\"x\"}".utf8), now: .distantPast)
    #expect(snapshot.cacheHitRatio == nil)
    #expect(snapshot.costUSD == nil)
    #expect(snapshot.contextTokens == nil)
}

@Test("session store publishes parsed statusline snapshots") @MainActor
func sessionStorePublishesSnapshots() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let statuslines = root.appendingPathComponent("sessions")
    let projects = root.appendingPathComponent("projects")
    try FileManager.default.createDirectory(at: statuslines, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: projects, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try Data(contentsOf: fixture("statusline.json")).write(to: statuslines.appendingPathComponent("fixture-session.json"))
    let store = SessionStore(sessionsDirectory: statuslines, projectsDirectory: projects, now: { Date(timeIntervalSince1970: 1_791_778_800) })
    store.refresh()
    #expect(store.sessions.map(\.sessionID) == ["fixture-session"])
    #expect(store.sessions.first?.name == "Fixture")
}

private func fixture(_ name: String) -> URL {
    Bundle.module.resourceURL!.appendingPathComponent("Fixtures/\(name)")
}
