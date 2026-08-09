import CodexBarCore
import Foundation
import Testing
@testable import CodexBar

struct MenuCardDeepSeekTests {
    private static func sampleDeepSeekSummary(now: Date = Date()) -> DeepSeekUsageSummary {
        DeepSeekUsageSummary(
            todayTokens: 123,
            currentMonthTokens: 456,
            todayCost: 0.0123,
            currentMonthCost: 0.0456,
            requestCount: 7,
            currentMonthRequestCount: 8,
            topModel: "deepseek-chat",
            categoryBreakdown: [
                DeepSeekCategoryBreakdown(category: .promptCacheHitToken, tokens: 10, cost: 0.001),
                DeepSeekCategoryBreakdown(category: .promptCacheMissToken, tokens: 20, cost: 0.002),
                DeepSeekCategoryBreakdown(category: .responseToken, tokens: 30, cost: 0.003),
            ],
            daily: [
                DeepSeekDailyUsage(date: "2026-05-26", totalTokens: 456, cost: 0.0456, requestCount: 8),
            ],
            currency: "CNY",
            updatedAt: now)
    }

    private static func makeSnapshot(now: Date, usageSummary: DeepSeekUsageSummary? = nil) -> UsageSnapshot {
        DeepSeekUsageSnapshot(
            isAvailable: true,
            currency: "USD",
            totalBalance: 9.32,
            grantedBalance: 0,
            toppedUpBalance: 9.32,
            usageSummary: usageSummary,
            updatedAt: now)
            .toUsageSnapshot()
    }

    @Test
    func `model shows spend and balance rows instead of a single percentage metric`() throws {
        let now = Date()
        // Use a properly enriched snapshot so balance fields are numeric (not just resetDescription).
        let snapshot = Self.makeSnapshot(now: now)
        let metadata = try #require(ProviderDefaults.metadata[.deepseek])

        let model = UsageMenuCardView.Model.make(.init(
            provider: .deepseek,
            metadata: metadata,
            snapshot: snapshot,
            credits: nil,
            creditsError: nil,
            dashboard: nil,
            dashboardError: nil,
            tokenSnapshot: nil,
            tokenError: nil,
            account: AccountInfo(email: nil, plan: nil),
            isRefreshing: false,
            lastError: nil,
            usageBarsShowUsed: false,
            resetTimeDisplayStyle: .countdown,
            tokenCostUsageEnabled: false,
            showOptionalCreditsAndExtraUsage: true,
            hidePersonalInfo: false,
            now: now))

        // Card shows: Today spend, This month spend, Balance — no raw percentage metrics.
        let today = try #require(model.metrics.first { $0.id == "deepseek-today-spend" })
        #expect(today.title == "Today")
        #expect(today.statusText == "—") // no usage summary in this snapshot
        #expect(today.resetText == nil)

        let balance = try #require(model.metrics.first { $0.id == "deepseek-balance" })
        #expect(balance.title == "Balance")
        // Balance = $9.32, Paid $9.32, Granted $0.00
        #expect(balance.statusText == "$9.32")
        #expect(balance.detailText?.contains("$9.32") == true)
        #expect(balance.resetText == nil)

        // Verify no raw-percent (usedPercent / remainingPercent) metric is present.
        #expect(model.metrics.allSatisfy { $0.id != "primary" && $0.id != "secondary" })
    }

    @Test
    func `model hides optional deepseek usage when extras disabled`() throws {
        let now = Date()
        let metadata = try #require(ProviderDefaults.metadata[.deepseek])
        let snapshot = Self.makeSnapshot(now: now, usageSummary: Self.sampleDeepSeekSummary(now: now))

        let model = UsageMenuCardView.Model.make(.init(
            provider: .deepseek,
            metadata: metadata,
            snapshot: snapshot,
            credits: nil,
            creditsError: nil,
            dashboard: nil,
            dashboardError: nil,
            tokenSnapshot: nil,
            tokenError: nil,
            account: AccountInfo(email: nil, plan: nil),
            isRefreshing: false,
            lastError: nil,
            usageBarsShowUsed: false,
            resetTimeDisplayStyle: .countdown,
            tokenCostUsageEnabled: false,
            showOptionalCreditsAndExtraUsage: false,
            hidePersonalInfo: false,
            now: now))

        #expect(model.inlineUsageDashboard == nil)
        #expect(model.usageNotes.isEmpty)
    }

    @Test
    func `model shows optional deepseek usage when extras enabled`() throws {
        let now = Date()
        let metadata = try #require(ProviderDefaults.metadata[.deepseek])
        let snapshot = Self.makeSnapshot(now: now, usageSummary: Self.sampleDeepSeekSummary(now: now))

        let model = UsageMenuCardView.Model.make(.init(
            provider: .deepseek,
            metadata: metadata,
            snapshot: snapshot,
            credits: nil,
            creditsError: nil,
            dashboard: nil,
            dashboardError: nil,
            tokenSnapshot: nil,
            tokenError: nil,
            account: AccountInfo(email: nil, plan: nil),
            isRefreshing: false,
            lastError: nil,
            usageBarsShowUsed: false,
            resetTimeDisplayStyle: .countdown,
            tokenCostUsageEnabled: false,
            showOptionalCreditsAndExtraUsage: true,
            hidePersonalInfo: false,
            now: now))

        #expect(model.inlineUsageDashboard?.accessibilityLabel == "DeepSeek 30 day token usage trend")
        #expect(model.usageNotes.contains { $0.contains("Today:") })
    }
}
