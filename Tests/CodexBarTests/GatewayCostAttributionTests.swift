import Foundation
import Testing
@testable import CodexBarCore

/// GLM runs through Claude Code against z.ai's Anthropic-compatible gateway, so its turns land in
/// the ordinary `~/.claude/projects` transcripts. Before the split they were counted as Claude
/// usage, because the scanner accepted any assistant row carrying a model and a usage block.
@Suite struct GatewayCostAttributionTests {
    private func transcript(models: [String]) -> String {
        models.enumerated().map { index, model in
            let line: [String: Any] = [
                "type": "assistant",
                "timestamp": "2026-08-29T1\(index):00:00.000Z",
                "requestId": "req_\(index)",
                "sessionId": "sess",
                "message": [
                    "id": "msg_\(index)",
                    "model": model,
                    "usage": [
                        "input_tokens": 1000,
                        "output_tokens": 500,
                        "cache_read_input_tokens": 2000,
                        "cache_creation_input_tokens": 0,
                    ],
                ],
            ]
            return String(data: try! JSONSerialization.data(withJSONObject: line), encoding: .utf8)!
        }.joined(separator: "\n")
    }

    private func scan(filter: CostUsageScanner.ClaudeLogProviderFilter) throws -> [String] {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("glm-split-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("session.jsonl")
        try self.transcript(models: ["claude-opus-5", "glm-5.3", "glm-5.3-flash"])
            .write(to: file, atomically: true, encoding: .utf8)

        let range = CostUsageScanner.CostUsageDayRange(
            since: Date(timeIntervalSince1970: 1_756_000_000),
            until: Date(timeIntervalSince1970: 1_790_000_000))
        let result = CostUsageScanner.parseClaudeFile(
            fileURL: file,
            range: range,
            providerFilter: filter)
        return result.days.values.flatMap { $0.keys }.sorted()
    }

    @Test func `claude scan no longer absorbs GLM turns`() throws {
        #expect(try self.scan(filter: .excludeVertexAI) == ["claude-opus-5"])
    }

    @Test func `glm filter selects only the gateway turns`() throws {
        #expect(try self.scan(filter: .glmOnly) == ["glm-5.3", "glm-5.3-flash"])
    }

    @Test func `unfiltered scan still sees everything`() throws {
        #expect(try self.scan(filter: .all) == ["claude-opus-5", "glm-5.3", "glm-5.3-flash"])
    }

    @Test func `GLM model detection is prefix based and case insensitive`() {
        #expect(CostUsageScanner.modelNameLooksGLM("glm-5.3"))
        #expect(CostUsageScanner.modelNameLooksGLM("GLM-4.6"))
        #expect(!CostUsageScanner.modelNameLooksGLM("claude-opus-5"))
        #expect(!CostUsageScanner.modelNameLooksGLM("kimi-k3"))
    }

    @Test func `kimi CLI models map onto metered Moonshot equivalents`() {
        #expect(CostUsageScanner.moonshotMeteredModelID(forCLIModel: "kimi-code/kimi-for-coding")
            == "kimi-k2.7-code")
        #expect(CostUsageScanner.moonshotMeteredModelID(forCLIModel: "kimi-for-coding-highspeed")
            == "kimi-k2.7-code-highspeed")
        #expect(CostUsageScanner.moonshotMeteredModelID(forCLIModel: "k3") == "kimi-k3")
    }

    @Test func `kimi configured model reads the top level default only`() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("kimi-cfg-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let cfg = dir.appendingPathComponent("config.toml")
        try """
        default_model = "kimi-code/kimi-for-coding"
        [models."kimi-code/k3"]
        model = "k3"
        default_model = "should-be-ignored"
        """.write(to: cfg, atomically: true, encoding: .utf8)
        #expect(CostUsageScanner.kimiConfiguredModel(configURL: cfg) == "kimi-code/kimi-for-coding")
    }

    @Test func `legacy kimi wire logs still aggregate per day`() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("kimi-legacy-\(UUID().uuidString)", isDirectory: true)
        let session = root.appendingPathComponent("workspace/session", isDirectory: true)
        try FileManager.default.createDirectory(at: session, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let lines: [[String: Any]] = [
            ["timestamp": 1_787_054_400.0, "message": ["type": "StatusUpdate", "payload": ["token_usage": [
                "input_other": 100, "output": 20, "input_cache_read": 900, "input_cache_creation": 5,
            ]]]],
            ["timestamp": 1_787_058_000.0, "message": ["type": "StatusUpdate", "payload": ["token_usage": [
                "input_other": 50, "output": 10, "input_cache_read": 400, "input_cache_creation": 0,
            ]]]],
        ]
        try self.write(lines, to: session.appendingPathComponent("wire.jsonl"))

        let entry = try #require(self.scanKimi(root: root).data.first)
        #expect(entry.inputTokens == 150)
        #expect(entry.outputTokens == 30)
        #expect(entry.cacheReadTokens == 1300)
        #expect(entry.cacheCreationTokens == 5)
        #expect(entry.totalTokens == 1485)
        #expect(entry.requestCount == 2)
    }

    /// The current CLI records the serving model per turn, so a day mixing k3 and the coding-plan
    /// model must price each lane at its own rate rather than a single assumed model.
    @Test func `usage records price each model lane separately`() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("kimi-new-\(UUID().uuidString)", isDirectory: true)
        let session = root.appendingPathComponent("wd_x/session_y/agents/main", isDirectory: true)
        try FileManager.default.createDirectory(at: session, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let lines: [[String: Any]] = [
            self.usageRecord(millis: 1_787_054_400_000, scope: "turn", model: "kimi-code/k3",
                             input: 1000, output: 100, cacheRead: 5000),
            self.usageRecord(millis: 1_787_058_000_000, scope: "turn",
                             model: "kimi-code/kimi-for-coding",
                             input: 200, output: 50, cacheRead: 1000),
        ]
        try self.write(lines, to: session.appendingPathComponent("wire.jsonl"))

        let entry = try #require(self.scanKimi(root: root).data.first)
        #expect(entry.inputTokens == 1200)
        #expect(entry.outputTokens == 150)
        #expect(entry.cacheReadTokens == 6000)
        #expect(entry.requestCount == 2)
        let names = (entry.modelBreakdowns ?? []).map(\.modelName).sorted()
        #expect(names == ["kimi-k2.7-code", "kimi-k3"])
    }

    /// `session`-scope rows restate the running session total. Counting them alongside the turn
    /// rows silently doubles every session.
    @Test func `session scope usage records are not double counted`() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("kimi-scope-\(UUID().uuidString)", isDirectory: true)
        let session = root.appendingPathComponent("wd_x/session_y/agents/main", isDirectory: true)
        try FileManager.default.createDirectory(at: session, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let lines: [[String: Any]] = [
            self.usageRecord(millis: 1_787_054_400_000, scope: "turn", model: "kimi-code/k3",
                             input: 1000, output: 100, cacheRead: 5000),
            self.usageRecord(millis: 1_787_058_000_000, scope: "session", model: "kimi-code/k3",
                             input: 1000, output: 100, cacheRead: 5000),
        ]
        try self.write(lines, to: session.appendingPathComponent("wire.jsonl"))

        let entry = try #require(self.scanKimi(root: root).data.first)
        #expect(entry.inputTokens == 1000)
        #expect(entry.outputTokens == 100)
        #expect(entry.requestCount == 1)
    }

    // MARK: - Helpers

    private func usageRecord(
        millis: Double, scope: String, model: String,
        input: Int, output: Int, cacheRead: Int) -> [String: Any]
    {
        [
            "type": "usage.record",
            "time": millis,
            "usageScope": scope,
            "model": model,
            "usage": [
                "inputOther": input, "output": output,
                "inputCacheRead": cacheRead, "inputCacheCreation": 0,
            ],
        ]
    }

    private func write(_ lines: [[String: Any]], to url: URL) throws {
        let text = lines
            .map { String(data: try! JSONSerialization.data(withJSONObject: $0), encoding: .utf8)! }
            .joined(separator: "\n")
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    private func scanKimi(root: URL) -> CostUsageDailyReport {
        var options = CostUsageScanner.Options()
        options.kimiSessionsRoots = [root]
        return (try? CostUsageScanner.loadKimiDaily(
            range: CostUsageScanner.CostUsageDayRange(
                since: Date(timeIntervalSince1970: 1_786_000_000),
                until: Date(timeIntervalSince1970: 1_790_000_000)),
            options: options)) ?? CostUsageDailyReport(data: [], summary: nil)
    }
}
