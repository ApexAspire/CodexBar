import CodexBarCore
import Foundation
import Testing
@testable import CodexBar

struct ClaudeExtraRateWindowMenuCardTests {
    @Test
    func `claude model includes routines and fable bars when present`() throws {
        let now = Date()
        let identity = ProviderIdentitySnapshot(
            providerID: .claude,
            accountEmail: nil,
            accountOrganization: nil,
            loginMethod: "Max")
        let snapshot = UsageSnapshot(
            primary: RateWindow(
                usedPercent: 2,
                windowMinutes: nil,
                resetsAt: now.addingTimeInterval(3600),
                resetDescription: nil),
            secondary: RateWindow(
                usedPercent: 8,
                windowMinutes: 10080,
                resetsAt: now.addingTimeInterval(7200),
                resetDescription: nil),
            tertiary: RateWindow(
                usedPercent: 16,
                windowMinutes: 10080,
                resetsAt: now.addingTimeInterval(7800),
                resetDescription: nil),
            extraRateWindows: [
                NamedRateWindow(
                    id: "claude-routines",
                    title: "Daily Routines",
                    window: RateWindow(
                        usedPercent: 7,
                        windowMinutes: 10080,
                        resetsAt: now.addingTimeInterval(9200),
                        resetDescription: nil)),
                NamedRateWindow(
                    id: "claude-fable",
                    title: "Fable",
                    window: RateWindow(
                        usedPercent: 68,
                        windowMinutes: 10080,
                        resetsAt: now.addingTimeInterval(9200),
                        resetDescription: nil)),
            ],
            updatedAt: now,
            identity: identity)
        let metadata = try #require(ProviderDefaults.metadata[.claude])
        let model = UsageMenuCardView.Model.make(.init(
            provider: .claude,
            metadata: metadata,
            snapshot: snapshot,
            credits: nil,
            creditsError: nil,
            dashboard: nil,
            dashboardError: nil,
            tokenSnapshot: nil,
            tokenError: nil,
            account: AccountInfo(email: "codex@example.com", plan: "plus"),
            isRefreshing: false,
            lastError: nil,
            usageBarsShowUsed: false,
            resetTimeDisplayStyle: .countdown,
            tokenCostUsageEnabled: false,
            showOptionalCreditsAndExtraUsage: true,
            hidePersonalInfo: false,
            now: now))

        #expect(model.metrics.map(\.title) == ["Session", "Weekly", "Sonnet", "Daily Routines", "Fable"])
    }
}
