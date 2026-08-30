import Foundation
import Testing
@testable import CodexBar
@testable import CodexBarCore

@MainActor
@Suite struct KimiInlineDashboardTests {
    private func entry(
        _ date: String, input: Int, output: Int, cacheRead: Int,
        cost: Double, model: String, requests: Int) -> CostUsageDailyReport.Entry
    {
        CostUsageDailyReport.Entry(
            date: date,
            inputTokens: input,
            outputTokens: output,
            cacheReadTokens: cacheRead,
            cacheCreationTokens: nil,
            totalTokens: input + output + cacheRead,
            requestCount: requests,
            costUSD: cost,
            modelsUsed: [model],
            modelBreakdowns: [CostUsageDailyReport.ModelBreakdown(
                modelName: model, costUSD: cost,
                totalTokens: input + output + cacheRead, requestCount: requests)])
    }

    private var snapshot: CostUsageTokenSnapshot {
        CostUsageTokenSnapshot(
            sessionTokens: 6300,
            sessionCostUSD: 2,
            last30DaysTokens: 11_600,
            last30DaysCostUSD: 3,
            daily: [
                self.entry("2026-08-29", input: 500, output: 100, cacheRead: 4700,
                           cost: 1, model: "kimi-k2.7-code", requests: 4),
                self.entry("2026-08-30", input: 300, output: 200, cacheRead: 5800,
                           cost: 2, model: "kimi-k3", requests: 6),
            ],
            updatedAt: Date())
    }

    @Test func `kimi card renders a usage trend from local session history`() {
        let dashboard = UsageMenuCardView.Model.kimiInlineDashboard(self.snapshot)
        #expect(dashboard.points.count == 2)
        #expect(dashboard.points.last?.value == 6300)
        // k3 carries the larger share, so it must be the headline model rather than the
        // alphabetically-first or config-default one.
        #expect(dashboard.kpis.first(where: { $0.title == "Models" })?.value.contains("k3") == true)
        #expect(dashboard.kpis.first?.value.contains("6.3K") == true)
        #expect(dashboard.detailLines.contains { $0.hasPrefix("requests") })
    }

    /// The card gate requires a non-empty daily history, so an empty snapshot must not reach the
    /// dashboard builder at all — a chart of nothing is worse than no chart.
    @Test func `empty history produces no points`() {
        let empty = CostUsageTokenSnapshot(
            sessionTokens: nil, sessionCostUSD: nil,
            last30DaysTokens: nil, last30DaysCostUSD: nil,
            daily: [], updatedAt: Date())
        #expect(UsageMenuCardView.Model.kimiInlineDashboard(empty).points.isEmpty)
    }
}
