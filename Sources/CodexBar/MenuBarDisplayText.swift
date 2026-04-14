import CodexBarCore
import Foundation

enum UsageSeverity: Equatable {
    case normal
    case warning
    case critical

    init(usedPercent: Double) {
        switch usedPercent {
        case 95...:
            self = .critical
        case 80...:
            self = .warning
        default:
            self = .normal
        }
    }

    static func from(window: RateWindow?, showUsed _: Bool) -> UsageSeverity {
        guard let window else {
            return .normal
        }
        return UsageSeverity(usedPercent: window.usedPercent)
    }

    var debugLabel: String {
        switch self {
        case .normal:
            return "ok"
        case .warning:
            return "warn"
        case .critical:
            return "crit"
        }
    }
}

struct StackedTextLines: Equatable {
    let session: String
    let weekly: String
    let sessionSeverity: UsageSeverity
    let weeklySeverity: UsageSeverity
}

enum MenuBarDisplayText {
    private static func percentValue(window: RateWindow?, showUsed: Bool) -> Int? {
        guard let window else { return nil }
        let percent = showUsed ? window.usedPercent : window.remainingPercent
        return Int(min(100, max(0, percent)).rounded())
    }

    static func percentText(window: RateWindow?, showUsed: Bool) -> String? {
        let percent = self.percentValue(window: window, showUsed: showUsed)
        guard let percent else {
            return nil
        }
        return "\(percent)%"
    }

    static func stackedPercentLines(
        sessionWindow: RateWindow?,
        weeklyWindow: RateWindow?,
        showUsed: Bool)
        -> StackedTextLines?
    {
        let session = self.percentValue(window: sessionWindow, showUsed: showUsed)
        let weekly = self.percentValue(window: weeklyWindow, showUsed: showUsed)
        guard session != nil || weekly != nil else {
            return nil
        }
        return StackedTextLines(
            session: "S:\(session.map { "\($0)%" } ?? "--")",
            weekly: "W:\(weekly.map { "\($0)%" } ?? "--")",
            sessionSeverity: UsageSeverity.from(window: sessionWindow, showUsed: showUsed),
            weeklySeverity: UsageSeverity.from(window: weeklyWindow, showUsed: showUsed))
    }

    static func paceText(pace: UsagePace?) -> String? {
        guard let pace else { return nil }
        let deltaValue = Int(abs(pace.deltaPercent).rounded())
        let sign = pace.deltaPercent >= 0 ? "+" : "-"
        return "\(sign)\(deltaValue)%"
    }

    static func displayText(
        mode: MenuBarDisplayMode,
        percentWindow: RateWindow?,
        pace: UsagePace? = nil,
        showUsed: Bool) -> String?
    {
        switch mode {
        case .percent:
            return self.percentText(window: percentWindow, showUsed: showUsed)
        case .pace:
            return self.paceText(pace: pace)
        case .both:
            guard let percent = percentText(window: percentWindow, showUsed: showUsed) else { return nil }
            // Fall back to percent-only when pace is unavailable (e.g. Copilot)
            guard let paceText = Self.paceText(pace: pace) else { return percent }
            return "\(percent) · \(paceText)"
        case .stackedText:
            return nil
        }
    }
}
