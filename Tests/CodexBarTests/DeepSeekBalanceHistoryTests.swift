import CodexBarCore
import Foundation
import Testing
@testable import CodexBar

struct DeepSeekBalanceHistoryTests {
    private static let base = Date(timeIntervalSince1970: 1_700_000_000)

    private static func sample(
        minutesAgo: Double,
        balance: Double,
        currency: String = "USD",
        now: Date = base) -> DeepSeekBalanceSample
    {
        DeepSeekBalanceSample(
            timestamp: now.addingTimeInterval(-minutesAgo * 60),
            totalBalance: balance,
            currency: currency)
    }

    @Test
    func `rolling spend sums balance drops`() {
        let samples = [
            Self.sample(minutesAgo: 180, balance: 10.00),
            Self.sample(minutesAgo: 120, balance: 9.50),
            Self.sample(minutesAgo: 60, balance: 9.10),
            Self.sample(minutesAgo: 0, balance: 9.00),
        ]
        let spend = DeepSeekBalanceHistory.rollingSpend(samples: samples, now: Self.base)
        #expect(spend != nil)
        #expect(abs((spend ?? 0) - 1.00) < 0.0001)
    }

    @Test
    func `top ups are ignored not counted as negative spend`() {
        let samples = [
            Self.sample(minutesAgo: 180, balance: 2.00),
            Self.sample(minutesAgo: 120, balance: 1.50),
            Self.sample(minutesAgo: 60, balance: 21.50), // +$20 top-up
            Self.sample(minutesAgo: 0, balance: 21.00),
        ]
        let spend = DeepSeekBalanceHistory.rollingSpend(samples: samples, now: Self.base)
        #expect(abs((spend ?? 0) - 1.00) < 0.0001)
    }

    @Test
    func `samples outside the 24h window are excluded`() {
        let samples = [
            Self.sample(minutesAgo: 30 * 60, balance: 50.00), // 30h ago
            Self.sample(minutesAgo: 60, balance: 10.00),
            Self.sample(minutesAgo: 0, balance: 9.00),
        ]
        let spend = DeepSeekBalanceHistory.rollingSpend(samples: samples, now: Self.base)
        #expect(abs((spend ?? 0) - 1.00) < 0.0001)
    }

    @Test
    func `fewer than two samples in window yields nil`() {
        #expect(DeepSeekBalanceHistory.rollingSpend(samples: [], now: Self.base) == nil)
        #expect(DeepSeekBalanceHistory.rollingSpend(
            samples: [Self.sample(minutesAgo: 0, balance: 9.00)],
            now: Self.base) == nil)
        #expect(DeepSeekBalanceHistory.rollingSpend(
            samples: [
                Self.sample(minutesAgo: 30 * 60, balance: 10.00),
                Self.sample(minutesAgo: 0, balance: 9.00),
            ],
            now: Self.base) == nil)
    }

    @Test
    func `store records then prunes stale and cross currency samples and round trips`() {
        let suiteName = "codexbar-tests-deepseek-balance-history"
        let store = DeepSeekBalanceHistoryStore(suiteName: suiteName)
        store.clear()
        defer { store.clear() }

        _ = store.record(totalBalance: 10.00, currency: "USD", now: Self.base.addingTimeInterval(-26 * 3600))
        _ = store.record(totalBalance: 9.50, currency: "USD", now: Self.base.addingTimeInterval(-3600))
        _ = store.record(totalBalance: 8.00, currency: "CNY", now: Self.base.addingTimeInterval(-1800))
        let samples = store.record(totalBalance: 7.50, currency: "CNY", now: Self.base)

        // The 26h-old sample is outside retention; the USD samples are dropped
        // on the currency switch to CNY.
        #expect(samples.count == 2)
        #expect(samples.allSatisfy { $0.currency == "CNY" })
        #expect(store.load() == samples)
    }

    @Test
    func `stacked tile prefers rolling 24h spend over platform today bucket`() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let summary = DeepSeekUsageSummary(
            todayTokens: 100,
            currentMonthTokens: 200,
            todayCost: 0.10,
            currentMonthCost: 0.50,
            requestCount: 1,
            currentMonthRequestCount: 2,
            topModel: nil,
            categoryBreakdown: [],
            daily: [],
            currency: "USD",
            updatedAt: now)
        let snapshot = DeepSeekUsageSnapshot(
            isAvailable: true,
            currency: "USD",
            totalBalance: 9.00,
            grantedBalance: 0,
            toppedUpBalance: 9.00,
            usageSummary: summary,
            updatedAt: now,
            last24hCost: 1.23)
            .toUsageSnapshot()

        let lines = MenuBarDisplayText.deepSeekStackedLines(snapshot: snapshot)
        #expect(lines?.session == "S:$1.23")
    }

    @Test
    func `stacked tile falls back to today cost while history warms`() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let summary = DeepSeekUsageSummary(
            todayTokens: 100,
            currentMonthTokens: 200,
            todayCost: 0.10,
            currentMonthCost: 0.50,
            requestCount: 1,
            currentMonthRequestCount: 2,
            topModel: nil,
            categoryBreakdown: [],
            daily: [],
            currency: "USD",
            updatedAt: now)
        let snapshot = DeepSeekUsageSnapshot(
            isAvailable: true,
            currency: "USD",
            totalBalance: 9.00,
            grantedBalance: 0,
            toppedUpBalance: 9.00,
            usageSummary: summary,
            updatedAt: now)
            .toUsageSnapshot()

        let lines = MenuBarDisplayText.deepSeekStackedLines(snapshot: snapshot)
        #expect(lines?.session == "S:$0.10")
    }
}
