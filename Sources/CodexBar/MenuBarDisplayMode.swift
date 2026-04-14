import Foundation

/// Controls what the menu bar displays when brand icon mode is enabled.
enum MenuBarDisplayMode: String, CaseIterable, Identifiable {
    case percent
    case pace
    case both
    case stackedText

    var id: String {
        self.rawValue
    }

    var label: String {
        switch self {
        case .percent: "Percent"
        case .pace: "Pace"
        case .both: "Both"
        case .stackedText: "Stacked Text"
        }
    }

    var description: String {
        switch self {
        case .percent: "Show remaining/used percentage (e.g. 45%)"
        case .pace: "Show pace indicator (e.g. +5%)"
        case .both: "Show both percentage and pace (e.g. 45% · +5%)"
        case .stackedText: "Show session and weekly percentages as stacked text (e.g. S: 4% / W: 71%)"
        }
    }
}
