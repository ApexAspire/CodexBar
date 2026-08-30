import Foundation

/// Reconstructs Kimi CLI token usage from its on-disk session wire logs.
///
/// The CLI moved home in August 2026 (`~/.kimi` → `~/.kimi-code`, recorded by a
/// `.migrated-to-kimi-code` marker) and changed its wire schema at the same time, so both layouts
/// are read. The workspace directories do not overlap between the two roots, so scanning both adds
/// pre-migration history without double counting.
///
/// Current schema — one `usage.record` per turn, with the model that served it:
///
///     {"type": "usage.record", "time": 1785694443488, "usageScope": "turn",
///      "model": "kimi-code/k3",
///      "usage": {"inputOther": 36847, "output": 126,
///                "inputCacheRead": 11264, "inputCacheCreation": 0}}
///
/// `usageScope` is the load-bearing field: `turn` rows are per-call and sum, while `session` rows
/// repeat the running session total and must be dropped or every session is counted twice.
///
/// Legacy schema — same figures under `message.payload.token_usage` in snake_case, with an epoch
/// *seconds* timestamp and no model recorded. Those rows fall back to the configured default model
/// for pricing; tokens are exact either way.
extension CostUsageScanner {
    struct KimiTokens {
        var input = 0
        var cacheRead = 0
        var cacheCreation = 0
        var output = 0
        var calls = 0

        var total: Int { self.input + self.cacheRead + self.cacheCreation + self.output }

        mutating func add(input: Int, cacheRead: Int, cacheCreation: Int, output: Int) {
            self.input += input
            self.cacheRead += cacheRead
            self.cacheCreation += cacheCreation
            self.output += output
            self.calls += 1
        }
    }

    /// Maps a Kimi CLI model id onto the equivalent metered Moonshot model in models.dev.
    /// Unmapped ids fall through unchanged so a newly released model can still resolve by name.
    static func moonshotMeteredModelID(forCLIModel cliModel: String) -> String {
        let trimmed = cliModel
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let bare = trimmed.contains("/") ? String(trimmed.split(separator: "/").last ?? "") : trimmed
        switch bare {
        case "kimi-for-coding": return "kimi-k2.7-code"
        case "kimi-for-coding-highspeed": return "kimi-k2.7-code-highspeed"
        case "k3", "k3-256k": return "kimi-k3"
        default: return bare.hasPrefix("kimi-") ? bare : "kimi-\(bare)"
        }
    }

    /// Current home first, then the pre-migration one.
    static func defaultKimiSessionsRoots(
        fileManager: FileManager = .default) -> [URL]
    {
        let home = fileManager.homeDirectoryForCurrentUser
        return [".kimi-code", ".kimi"].map {
            home.appendingPathComponent($0, isDirectory: true)
                .appendingPathComponent("sessions", isDirectory: true)
        }
    }

    /// Reads `default_model` out of the Kimi CLI's TOML config without pulling in a TOML parser —
    /// the key is a flat top-level assignment. Only used to price legacy rows, which record no model.
    static func kimiConfiguredModel(
        configURL: URL? = nil,
        fileManager: FileManager = .default) -> String?
    {
        let home = fileManager.homeDirectoryForCurrentUser
        let candidates: [URL] = if let configURL {
            [configURL]
        } else {
            [".kimi-code", ".kimi"].map {
                home.appendingPathComponent($0, isDirectory: true)
                    .appendingPathComponent("config.toml", isDirectory: false)
            }
        }

        for url in candidates {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            for rawLine in text.split(separator: "\n", omittingEmptySubsequences: true) {
                let line = rawLine.trimmingCharacters(in: .whitespaces)
                // Stop at the first table header: `default_model` is a top-level key, and the
                // `model` keys inside `[models.…]` are the catalogue, not the selection.
                if line.hasPrefix("[") { break }
                guard line.hasPrefix("default_model") else { continue }
                guard let eq = line.firstIndex(of: "=") else { continue }
                let value = line[line.index(after: eq)...]
                    .trimmingCharacters(in: .whitespaces)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                if !value.isEmpty { return value }
            }
        }
        return nil
    }

    static func loadKimiDaily(
        range: CostUsageDayRange,
        now: Date = Date(),
        options: Options = Options(),
        checkCancellation: CancellationCheck? = nil) throws -> CostUsageDailyReport
    {
        let roots = options.kimiSessionsRoots ?? Self.defaultKimiSessionsRoots()
        let fileManager = FileManager.default
        let fallbackModel = Self.moonshotMeteredModelID(
            forCLIModel: Self.kimiConfiguredModel() ?? "k3")
        let catalog = CostUsagePricing.modelsDevCatalog(now: now, cacheRoot: options.cacheRoot)

        // day -> metered model -> tokens
        var days: [String: [String: KimiTokens]] = [:]

        for root in roots {
            guard fileManager.fileExists(atPath: root.path) else { continue }
            guard let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants])
            else { continue }

            for case let fileURL as URL in enumerator {
                try checkCancellation?()
                guard fileURL.lastPathComponent == "wire.jsonl" else { continue }
                guard let text = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }

                for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
                    guard line.contains("usage") else { continue }
                    guard let data = line.data(using: .utf8),
                          let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let parsed = Self.parseKimiUsageRow(obj, fallbackModel: fallbackModel)
                    else { continue }

                    let dayKey = CostUsageDayRange.dayKey(from: parsed.timestamp)
                    guard CostUsageDayRange.isInRange(
                        dayKey: dayKey,
                        since: range.scanSinceKey,
                        until: range.scanUntilKey)
                    else { continue }

                    var models = days[dayKey] ?? [:]
                    var bucket = models[parsed.model] ?? KimiTokens()
                    bucket.add(
                        input: parsed.input,
                        cacheRead: parsed.cacheRead,
                        cacheCreation: parsed.cacheCreation,
                        output: parsed.output)
                    models[parsed.model] = bucket
                    days[dayKey] = models
                }
            }
        }

        return Self.buildKimiReport(days: days, catalog: catalog, cacheRoot: options.cacheRoot)
    }

    private struct KimiUsageRow {
        let timestamp: Date
        let model: String
        let input: Int
        let cacheRead: Int
        let cacheCreation: Int
        let output: Int
    }

    private static func parseKimiUsageRow(
        _ obj: [String: Any],
        fallbackModel: String) -> KimiUsageRow?
    {
        func intValue(_ dict: [String: Any], _ key: String) -> Int {
            max(0, (dict[key] as? NSNumber)?.intValue ?? 0)
        }

        let usage: [String: Any]
        let timestamp: Date
        let model: String
        let inputKey: String
        let cacheReadKey: String
        let cacheCreationKey: String

        if obj["type"] as? String == "usage.record" {
            // Session-scope rows restate the running total for the whole session; counting them
            // alongside the turn rows double-counts every session.
            guard (obj["usageScope"] as? String) == "turn" else { return nil }
            guard let raw = obj["usage"] as? [String: Any],
                  let millis = (obj["time"] as? NSNumber)?.doubleValue
            else { return nil }
            usage = raw
            timestamp = Date(timeIntervalSince1970: millis / 1000)
            model = Self.moonshotMeteredModelID(
                forCLIModel: (obj["model"] as? String) ?? fallbackModel)
            inputKey = "inputOther"
            cacheReadKey = "inputCacheRead"
            cacheCreationKey = "inputCacheCreation"
        } else {
            guard let message = obj["message"] as? [String: Any],
                  let payload = message["payload"] as? [String: Any],
                  let raw = payload["token_usage"] as? [String: Any],
                  let seconds = (obj["timestamp"] as? NSNumber)?.doubleValue
            else { return nil }
            usage = raw
            timestamp = Date(timeIntervalSince1970: seconds)
            model = fallbackModel
            inputKey = "input_other"
            cacheReadKey = "input_cache_read"
            cacheCreationKey = "input_cache_creation"
        }

        let input = intValue(usage, inputKey)
        let cacheRead = intValue(usage, cacheReadKey)
        let cacheCreation = intValue(usage, cacheCreationKey)
        let output = intValue(usage, "output")
        if input == 0, cacheRead == 0, cacheCreation == 0, output == 0 { return nil }

        return KimiUsageRow(
            timestamp: timestamp,
            model: model,
            input: input,
            cacheRead: cacheRead,
            cacheCreation: cacheCreation,
            output: output)
    }

    private static func buildKimiReport(
        days: [String: [String: KimiTokens]],
        catalog: ModelsDevCatalog?,
        cacheRoot: URL?) -> CostUsageDailyReport
    {
        var entries: [CostUsageDailyReport.Entry] = []
        var totalInput = 0
        var totalOutput = 0
        var totalCacheRead = 0
        var totalCacheCreation = 0
        var totalCost = 0.0
        var anyPriced = false

        for dayKey in days.keys.sorted() {
            guard let models = days[dayKey] else { continue }
            var day = KimiTokens()
            var dayCost: Double?
            var breakdowns: [CostUsageDailyReport.ModelBreakdown] = []

            for model in models.keys.sorted() {
                guard let bucket = models[model] else { continue }
                let cost = CostUsagePricing.gatewayCostUSD(
                    providerID: CostUsagePricing.moonshotModelsDevProviderID,
                    model: model,
                    inputTokens: bucket.input,
                    cacheReadInputTokens: bucket.cacheRead,
                    cacheCreationInputTokens: bucket.cacheCreation,
                    outputTokens: bucket.output,
                    modelsDevCatalog: catalog,
                    modelsDevCacheRoot: cacheRoot)
                if let cost {
                    dayCost = (dayCost ?? 0) + cost
                    anyPriced = true
                }
                day.input += bucket.input
                day.cacheRead += bucket.cacheRead
                day.cacheCreation += bucket.cacheCreation
                day.output += bucket.output
                day.calls += bucket.calls
                breakdowns.append(CostUsageDailyReport.ModelBreakdown(
                    modelName: model,
                    costUSD: cost,
                    totalTokens: bucket.total,
                    requestCount: bucket.calls))
            }

            totalInput += day.input
            totalOutput += day.output
            totalCacheRead += day.cacheRead
            totalCacheCreation += day.cacheCreation
            totalCost += dayCost ?? 0

            entries.append(CostUsageDailyReport.Entry(
                date: dayKey,
                inputTokens: day.input > 0 ? day.input : nil,
                outputTokens: day.output > 0 ? day.output : nil,
                cacheReadTokens: day.cacheRead > 0 ? day.cacheRead : nil,
                cacheCreationTokens: day.cacheCreation > 0 ? day.cacheCreation : nil,
                totalTokens: day.total,
                requestCount: day.calls > 0 ? day.calls : nil,
                costUSD: dayCost,
                modelsUsed: models.keys.sorted(),
                modelBreakdowns: breakdowns.isEmpty ? nil : breakdowns))
        }

        let summary = CostUsageDailyReport.Summary(
            totalInputTokens: totalInput,
            totalOutputTokens: totalOutput,
            cacheReadTokens: totalCacheRead,
            cacheCreationTokens: totalCacheCreation,
            totalTokens: totalInput + totalOutput + totalCacheRead + totalCacheCreation,
            totalCostUSD: anyPriced ? totalCost : nil)

        return CostUsageDailyReport(data: entries, summary: summary)
    }
}
