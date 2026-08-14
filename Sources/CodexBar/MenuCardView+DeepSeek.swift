import CodexBarCore
import Foundation

extension UsageMenuCardView.Model {
    /// Builds the dropdown metrics for the DeepSeek provider card.
    /// Shows today's spend, month-to-date spend, and current balance with granted/topped-up
    /// breakdown. Does not show limit bars since DeepSeek is a pay-as-you-go provider.
    static func deepSeekMetrics(snapshot: UsageSnapshot, input: Input) -> [Metric] {
        let usage = snapshot.deepseekUsage
        let symbol = (usage?.balanceCurrency ?? usage?.currency ?? "USD") == "CNY" ? "¥" : "$"

        var metrics: [Metric] = []

        // Rolling last-24h spend — computed from locally sampled balance deltas, because the
        // platform API only exposes per-day buckets in the platform's timezone. Matches the
        // S: figure in the stacked menu bar tile once history has warmed.
        if let last24h = usage?.last24hCost {
            metrics.append(Metric(
                id: "deepseek-24h-spend",
                title: L("Last 24h"),
                percent: 0,
                percentStyle: .used,
                statusText: String(format: "\(symbol)%.4f", max(0, last24h)),
                resetText: nil,
                detailText: nil,
                detailLeftText: nil,
                detailRightText: nil,
                pacePercent: nil,
                paceOnTop: true))
        }

        // Today's spend — sourced from the platform cost/amount API daily breakdown.
        let todaySpendText: String
        if let cost = usage?.todayCost {
            todaySpendText = String(format: "\(symbol)%.4f", max(0, cost))
        } else {
            todaySpendText = "—"
        }
        metrics.append(Metric(
            id: "deepseek-today-spend",
            title: L("Today"),
            percent: 0,
            percentStyle: .used,
            statusText: todaySpendText,
            resetText: nil,
            detailText: nil,
            detailLeftText: nil,
            detailRightText: nil,
            pacePercent: nil,
            paceOnTop: true))

        // Month-to-date spend.
        let monthSpendText: String
        if let cost = usage?.currentMonthCost {
            monthSpendText = String(format: "\(symbol)%.4f", max(0, cost))
        } else {
            monthSpendText = "—"
        }
        metrics.append(Metric(
            id: "deepseek-month-spend",
            title: L("This month"),
            percent: 0,
            percentStyle: .used,
            statusText: monthSpendText,
            resetText: nil,
            detailText: nil,
            detailLeftText: nil,
            detailRightText: nil,
            pacePercent: nil,
            paceOnTop: true))

        // Balance with granted/topped-up breakdown.
        if let totalBalance = usage?.totalBalance {
            let balanceText = String(format: "\(symbol)%.2f", totalBalance)
            let granted = usage?.grantedBalance ?? 0
            let toppedUp = usage?.toppedUpBalance ?? 0
            let breakdown = String(
                format: L("Paid: %@ · Granted: %@"),
                String(format: "\(symbol)%.2f", toppedUp),
                String(format: "\(symbol)%.2f", granted))
            metrics.append(Metric(
                id: "deepseek-balance",
                title: L("Balance"),
                percent: 0,
                percentStyle: .used,
                statusText: balanceText,
                resetText: nil,
                detailText: breakdown,
                detailLeftText: nil,
                detailRightText: nil,
                pacePercent: nil,
                paceOnTop: true))
        } else if let balanceDetail = snapshot.primary?.resetDescription,
                  !balanceDetail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            // Fallback: surface the pre-formatted balance string when numeric data is absent.
            metrics.append(Metric(
                id: "deepseek-balance",
                title: L("Balance"),
                percent: 0,
                percentStyle: .used,
                statusText: balanceDetail,
                resetText: nil,
                detailText: nil,
                detailLeftText: nil,
                detailRightText: nil,
                pacePercent: nil,
                paceOnTop: true))
        }

        return metrics
    }
}
