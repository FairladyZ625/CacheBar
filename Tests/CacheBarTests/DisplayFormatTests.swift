import Foundation
import Testing
@testable import CacheBarCore

let epoch = Date(timeIntervalSince1970: 1_791_778_800)

@Test("hit ratio renders as whole percent, nil stays nil")
func hitRatio() {
    #expect(DisplayFormat.hitRatioPercent(0.923) == "92%")
    #expect(DisplayFormat.hitRatioPercent(0) == "0%")
    #expect(DisplayFormat.hitRatioPercent(1) == "100%")
    #expect(DisplayFormat.hitRatioPercent(nil) == nil)
}

@Test("account usage percent is a 0...100 scale value")
func usagePercent() {
    #expect(DisplayFormat.usagePercent(62.4) == "62%")
    #expect(DisplayFormat.usagePercent(47) == "47%")
    #expect(DisplayFormat.usagePercent(nil) == nil)
}

@Test("cache countdown ticks in mm:ss and h:mm:ss, reports expired")
func cacheCountdown() {
    #expect(DisplayFormat.cacheCountdown(expiresAt: epoch.addingTimeInterval(41 * 60 + 32), now: epoch) == "41:32")
    #expect(DisplayFormat.cacheCountdown(expiresAt: epoch.addingTimeInterval(3_721), now: epoch) == "1:02:01")
    #expect(DisplayFormat.cacheCountdown(expiresAt: epoch.addingTimeInterval(59), now: epoch) == "00:59")
    #expect(DisplayFormat.cacheCountdown(expiresAt: epoch, now: epoch) == "已过期")
    #expect(DisplayFormat.cacheCountdown(expiresAt: epoch.addingTimeInterval(-5), now: epoch) == "已过期")
    #expect(DisplayFormat.cacheCountdown(expiresAt: nil, now: epoch) == nil)
}

@Test("reset countdown compacts to s/m/h/d and drops zero components")
func resetCountdown() {
    #expect(DisplayFormat.resetCountdown(resetsAt: epoch.addingTimeInterval(43), now: epoch) == "43s")
    #expect(DisplayFormat.resetCountdown(resetsAt: epoch.addingTimeInterval(2_821), now: epoch) == "47m")
    #expect(DisplayFormat.resetCountdown(resetsAt: epoch.addingTimeInterval(8_100), now: epoch) == "2h15m")
    #expect(DisplayFormat.resetCountdown(resetsAt: epoch.addingTimeInterval(7_200), now: epoch) == "2h")
    #expect(DisplayFormat.resetCountdown(resetsAt: epoch.addingTimeInterval(273_600), now: epoch) == "3d4h")
    #expect(DisplayFormat.resetCountdown(resetsAt: epoch.addingTimeInterval(86_400), now: epoch) == "1d")
    #expect(DisplayFormat.resetCountdown(resetsAt: epoch.addingTimeInterval(-10), now: epoch) == "0s")
    #expect(DisplayFormat.resetCountdown(resetsAt: nil, now: epoch) == nil)
}

@Test("token counts compact with one decimal and trimmed zeros")
func tokenCounts() {
    #expect(DisplayFormat.tokenCount(0) == "0")
    #expect(DisplayFormat.tokenCount(842) == "842")
    #expect(DisplayFormat.tokenCount(96_000) == "96k")
    #expect(DisplayFormat.tokenCount(148_300) == "148.3k")
    #expect(DisplayFormat.tokenCount(999_500) == "999.5k")
    #expect(DisplayFormat.tokenCount(1_234_567) == "1.2M")
    #expect(DisplayFormat.tokenCount(nil) == nil)
}

@Test("usd keeps four decimals under one dollar, two above")
func usd() {
    #expect(DisplayFormat.usd(4.21) == "$4.21")
    #expect(DisplayFormat.usd(21.3) == "$21.30")
    #expect(DisplayFormat.usd(0.482) == "$0.482")
    #expect(DisplayFormat.usd(0.5) == "$0.5")
    #expect(DisplayFormat.usd(0) == "$0")
    #expect(DisplayFormat.usd(nil) == nil)
}
