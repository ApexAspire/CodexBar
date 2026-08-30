import Foundation

extension DeepSeekUsageSummary {
    /// Projects DeepSeek's platform usage analysis onto the shared cost-history model that
    /// `CostHistoryChartMenuView` renders.
    ///
    /// Unlike Claude and Codex — whose daily history is reconstructed locally from CLI session
    /// logs and priced through `CostUsagePricing` — DeepSeek reports genuine per-day token and
    /// spend figures from its own platform API, so nothing here is estimated. The API is scoped to
    /// the current calendar month in DeepSeek's platform timezone, which is why the window label is
    /// "This month" rather than a rolling 30 days.
    public func toCostUsageTokenSnapshot(historyDays: Int = 30) -> CostUsageTokenSnapshot {
        let clampedHistoryDays = max(1, min(365, historyDays))
        let entries = self.daily.map { day in
            CostUsageDailyReport.Entry(
                date: day.date,
                inputTokens: day.cacheMissTokens > 0 ? day.cacheMissTokens : nil,
                outputTokens: day.outputTokens > 0 ? day.outputTokens : nil,
                cacheReadTokens: day.cacheHitTokens > 0 ? day.cacheHitTokens : nil,
                cacheCreationTokens: nil,
                totalTokens: day.totalTokens,
                requestCount: day.requestCount > 0 ? day.requestCount : nil,
                costUSD: day.cost.map { max($0, 0) },
                modelsUsed: nil,
                modelBreakdowns: nil)
        }

        return CostUsageTokenSnapshot(
            sessionTokens: self.todayTokens > 0 ? self.todayTokens : nil,
            sessionCostUSD: self.todayCost.map { max($0, 0) },
            sessionRequests: self.requestCount > 0 ? self.requestCount : nil,
            last30DaysTokens: self.currentMonthTokens > 0 ? self.currentMonthTokens : nil,
            last30DaysCostUSD: self.currentMonthCost.map { max($0, 0) },
            last30DaysRequests: self.currentMonthRequestCount > 0 ? self.currentMonthRequestCount : nil,
            currencyCode: self.currency,
            historyDays: entries.isEmpty ? clampedHistoryDays : max(1, min(365, entries.count)),
            historyLabel: "This month",
            daily: entries,
            updatedAt: self.updatedAt)
    }
}
