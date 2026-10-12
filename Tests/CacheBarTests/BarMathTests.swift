import Foundation
import Testing
@testable import CacheBarCore

let barEpoch = Date(timeIntervalSince1970: 1_791_778_800)

@Test("quota fill maps used percent to fraction and clamps out-of-range")
func quotaFill() {
    #expect(BarMath.quotaFill(usedPercent: 50) == 0.5)
    #expect(BarMath.quotaFill(usedPercent: 0) == 0)
    #expect(BarMath.quotaFill(usedPercent: 100) == 1)
    #expect(BarMath.quotaFill(usedPercent: 120) == 1)
    #expect(BarMath.quotaFill(usedPercent: -10) == 0)
    #expect(BarMath.quotaFill(usedPercent: nil) == nil)
}

@Test("lifetime fill divides by tier span: 5m 300s, 1h and unknown 3600s")
func lifetimeFillTiers() {
    #expect(BarMath.lifetimeFill(expiresAt: barEpoch.addingTimeInterval(150), ttl: .fiveMinutes, now: barEpoch) == 0.5)
    #expect(BarMath.lifetimeFill(expiresAt: barEpoch.addingTimeInterval(1_800), ttl: .oneHour, now: barEpoch) == 0.5)
    #expect(BarMath.lifetimeFill(expiresAt: barEpoch.addingTimeInterval(1_800), ttl: nil, now: barEpoch) == 0.5)
}

@Test("lifetime fill is 0 once expired and clamps over-span remaining")
func lifetimeFillBounds() {
    #expect(BarMath.lifetimeFill(expiresAt: barEpoch.addingTimeInterval(-60), ttl: .oneHour, now: barEpoch) == 0)
    #expect(BarMath.lifetimeFill(expiresAt: barEpoch, ttl: .fiveMinutes, now: barEpoch) == 0)
    #expect(BarMath.lifetimeFill(expiresAt: barEpoch.addingTimeInterval(400), ttl: .fiveMinutes, now: barEpoch) == 1)
    #expect(BarMath.lifetimeFill(expiresAt: barEpoch.addingTimeInterval(7_200), ttl: nil, now: barEpoch) == 1)
    #expect(BarMath.lifetimeFill(expiresAt: nil, ttl: .oneHour, now: barEpoch) == nil)
}

@Test("context fill needs both token counts and a positive window")
func contextFill() {
    #expect(BarMath.contextFill(contextTokens: 100_000, contextWindowTokens: 200_000) == 0.5)
    #expect(BarMath.contextFill(contextTokens: 250_000, contextWindowTokens: 200_000) == 1)
    #expect(BarMath.contextFill(contextTokens: 0, contextWindowTokens: 200_000) == 0)
    #expect(BarMath.contextFill(contextTokens: nil, contextWindowTokens: 200_000) == nil)
    #expect(BarMath.contextFill(contextTokens: 64_000, contextWindowTokens: nil) == nil)
    #expect(BarMath.contextFill(contextTokens: 64_000, contextWindowTokens: 0) == nil)
}
