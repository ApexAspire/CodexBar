import Foundation

// MARK: - Sample

/// One observed balance reading. The rolling-spend computation needs only the
/// total balance: spend shows up as drops between consecutive readings, and
/// top-ups (which raise the balance) must not be counted as negative spend.
public struct DeepSeekBalanceSample: Codable, Sendable, Equatable {
    public let timestamp: Date
    public let totalBalance: Double
    public let currency: String

    public init(timestamp: Date, totalBalance: Double, currency: String) {
        self.timestamp = timestamp
        self.totalBalance = totalBalance
        self.currency = currency
    }
}

// MARK: - Rolling-spend computation

public enum DeepSeekBalanceHistory {
    /// The DeepSeek platform usage API only exposes per-day buckets in the
    /// platform's timezone, so a true rolling 24h figure has to come from
    /// balance deltas sampled locally.
    public static let rollingWindow: TimeInterval = 24 * 60 * 60
    /// Keep a little more than the window so the sample just outside 24h
    /// still anchors the first delta.
    static let retentionWindow: TimeInterval = 25 * 60 * 60
    static let sampleCap = 600

    /// Sum of balance drops between consecutive samples inside the window.
    /// Increases (top-ups, refunds, granted credits) are ignored rather than
    /// subtracted, so a top-up mid-window cannot mask real spend.
    /// Returns nil until at least two samples fall inside the window.
    public static func rollingSpend(
        samples: [DeepSeekBalanceSample],
        now: Date,
        window: TimeInterval = rollingWindow) -> Double?
    {
        let cutoff = now.addingTimeInterval(-window)
        let windowed = samples
            .filter { $0.timestamp >= cutoff && $0.timestamp <= now }
            .sorted { $0.timestamp < $1.timestamp }
        guard windowed.count >= 2 else { return nil }
        var spend = 0.0
        for (previous, current) in zip(windowed, windowed.dropFirst())
            where previous.currency == current.currency
        {
            spend += max(0, previous.totalBalance - current.totalBalance)
        }
        return spend
    }

    /// Drop samples outside the retention window, samples in a different
    /// currency than the newest reading (a currency switch resets history),
    /// and cap the total count oldest-first.
    static func pruned(
        samples: [DeepSeekBalanceSample],
        now: Date,
        currency: String) -> [DeepSeekBalanceSample]
    {
        let cutoff = now.addingTimeInterval(-self.retentionWindow)
        var kept = samples
            .filter { $0.timestamp >= cutoff && $0.currency == currency }
            .sorted { $0.timestamp < $1.timestamp }
        if kept.count > self.sampleCap {
            kept.removeFirst(kept.count - self.sampleCap)
        }
        return kept
    }
}

// MARK: - Persistence

/// UserDefaults-backed store for balance samples. CodexBar polls providers on
/// its refresh cadence, so recording one sample per successful balance fetch
/// yields plenty of resolution for a 24h window.
public struct DeepSeekBalanceHistoryStore: Sendable {
    public static let defaultsKey = "deepseekBalanceHistoryV1"

    private let suiteName: String?

    public init(suiteName: String? = nil) {
        self.suiteName = suiteName
    }

    private var defaults: UserDefaults {
        if let suiteName, let suite = UserDefaults(suiteName: suiteName) {
            return suite
        }
        return .standard
    }

    public func load() -> [DeepSeekBalanceSample] {
        guard let data = self.defaults.data(forKey: Self.defaultsKey) else { return [] }
        return (try? JSONDecoder().decode([DeepSeekBalanceSample].self, from: data)) ?? []
    }

    /// Append a reading, prune, persist, and return the updated history.
    @discardableResult
    public func record(
        totalBalance: Double,
        currency: String,
        now: Date = Date()) -> [DeepSeekBalanceSample]
    {
        var samples = self.load()
        samples.append(DeepSeekBalanceSample(timestamp: now, totalBalance: totalBalance, currency: currency))
        samples = DeepSeekBalanceHistory.pruned(samples: samples, now: now, currency: currency)
        if let data = try? JSONEncoder().encode(samples) {
            self.defaults.set(data, forKey: Self.defaultsKey)
        }
        return samples
    }

    public func clear() {
        self.defaults.removeObject(forKey: Self.defaultsKey)
    }
}
