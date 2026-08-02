import Foundation
import Testing
@testable import CodexBarCore

struct ClaudeWebUsageExtraWindowTests {
    @Test
    func `parses claude web API sonnet usage response`() throws {
        let json = """
        {
          "five_hour": { "utilization": 9, "resets_at": "2025-12-23T16:00:00.000Z" },
          "seven_day_sonnet": { "utilization": 6, "resets_at": "2025-12-30T23:00:00.000Z" }
        }
        """
        let data = Data(json.utf8)
        let parsed = try ClaudeWebAPIFetcher._parseUsageResponseForTesting(data)
        #expect(parsed.opusPercentUsed == 6)
    }

    @Test
    func `ignores merged claude web API omelette usage window`() throws {
        let json = """
        {
          "five_hour": { "utilization": 9, "resets_at": "2025-12-23T16:00:00.000Z" },
          "seven_day_omelette": { "utilization": 26, "resets_at": "2025-12-30T23:00:00.000Z" },
          "seven_day_cowork": { "utilization": 11, "resets_at": "2025-12-31T23:00:00.000Z" }
        }
        """
        let data = Data(json.utf8)
        let parsed = try ClaudeWebAPIFetcher._parseUsageResponseForTesting(data)
        #expect(parsed.extraRateWindows.count == 1)
        #expect(parsed.extraRateWindows.contains { $0.id == "claude-design" } == false)
        #expect(parsed.extraRateWindows.first(where: { $0.id == "claude-routines" })?.window.usedPercent == 11)
    }

    @Test
    func `parses claude web API scoped fable weekly limit`() throws {
        let json = """
        {
          "five_hour": { "utilization": 9, "resets_at": "2026-08-02T16:00:00.000Z" },
          "seven_day": { "utilization": 40, "resets_at": "2026-08-06T16:00:00.000Z" },
          "limits": [
            {
              "kind": "weekly_scoped",
              "group": "weekly",
              "percent": 68,
              "resets_at": "2026-08-06T16:00:00.000Z",
              "scope": {
                "model": {
                  "id": "claude-fable-5",
                  "display_name": "Fable"
                }
              }
            }
          ]
        }
        """
        let data = Data(json.utf8)
        let parsed = try ClaudeWebAPIFetcher._parseUsageResponseForTesting(data)
        let fable = try #require(parsed.extraRateWindows.first { $0.id == "claude-fable" })
        #expect(fable.title == "Fable")
        #expect(fable.window.usedPercent == 68)
        #expect(fable.window.windowMinutes == 7 * 24 * 60)
        #expect(fable.window.resetsAt != nil)
    }

    @Test
    func `parses claude web API cowork null as zero routines window`() throws {
        let json = """
        {
          "five_hour": { "utilization": 9, "resets_at": "2025-12-23T16:00:00.000Z" },
          "seven_day_omelette": { "utilization": 26, "resets_at": "2025-12-30T23:00:00.000Z" },
          "seven_day_cowork": null
        }
        """
        let data = Data(json.utf8)
        let parsed = try ClaudeWebAPIFetcher._parseUsageResponseForTesting(data)
        #expect(parsed.extraRateWindows.first(where: { $0.id == "claude-routines" })?.window.usedPercent == 0)
        #expect(parsed.extraRateWindows.contains { $0.id == "claude-design" } == false)
    }
}
