import CodexBarMacroSupport
import Foundation

@ProviderDescriptorRegistration
@ProviderDescriptorDefinition
public enum DeepSeekProviderDescriptor {
    static func makeDescriptor() -> ProviderDescriptor {
        ProviderDescriptor(
            id: .deepseek,
            metadata: ProviderMetadata(
                id: .deepseek,
                displayName: "DeepSeek",
                sessionLabel: "Balance",
                weeklyLabel: "Balance",
                opusLabel: nil,
                supportsOpus: false,
                supportsCredits: false,
                creditsHint: "",
                toggleTitle: "Show DeepSeek usage",
                cliName: "deepseek",
                defaultEnabled: false,
                isPrimaryProvider: false,
                usesAccountFallback: false,
                browserCookieOrder: nil,
                dashboardURL: "https://platform.deepseek.com/usage",
                statusPageURL: nil,
                statusLinkURL: "https://status.deepseek.com"),
            branding: ProviderBranding(
                iconStyle: .deepseek,
                iconResourceName: "ProviderIcon-deepseek",
                color: ProviderColor(red: 0.32, green: 0.49, blue: 0.94)),
            tokenCost: ProviderTokenCostConfig(
                // The per-day usage analysis lives on platform.deepseek.com's web-console API,
                // which refuses the `sk-` API key this provider authenticates with (HTTP 200 with
                // `code: 40003`). `DeepSeekUsageSummary` parses the daily lanes correctly and is
                // covered by tests, so flipping this back on is all that a future cookie-backed
                // source would need — but with an API key there is no history to chart.
                supportsTokenCost: false,
                noDataMessage: { "DeepSeek per-day cost history needs web-console sign-in." }),
            fetchPlan: ProviderFetchPlan(
                sourceModes: [.auto, .api],
                pipeline: ProviderFetchPipeline(resolveStrategies: { _ in [DeepSeekAPIFetchStrategy()] })),
            cli: ProviderCLIConfig(
                name: "deepseek",
                aliases: ["deep-seek", "ds"],
                versionDetector: nil))
    }
}

struct DeepSeekAPIFetchStrategy: ProviderFetchStrategy {
    let id: String = "deepseek.api"
    let kind: ProviderFetchKind = .apiToken

    func isAvailable(_ context: ProviderFetchContext) async -> Bool {
        Self.resolveToken(environment: context.env) != nil
    }

    func fetch(_ context: ProviderFetchContext) async throws -> ProviderFetchResult {
        guard let apiKey = Self.resolveToken(environment: context.env) else {
            throw DeepSeekUsageError.missingCredentials
        }
        let usage = try await DeepSeekUsageFetcher.fetchUsage(
            apiKey: apiKey,
            includeOptionalUsage: context.includeOptionalUsage)

        return self.makeResult(
            usage: usage.toUsageSnapshot(),
            sourceLabel: "api")
    }

    func shouldFallback(on _: Error, context _: ProviderFetchContext) -> Bool {
        false
    }

    private static func resolveToken(environment: [String: String]) -> String? {
        ProviderTokenResolver.deepseekToken(environment: environment)
    }
}
