import Foundation
import Testing
@testable import MaohuobanDiagnostics

extension DiagnosticsPipelineTests {
    @Test("诊断包会写入可直接给 LLM 分析的 prompt 文件")
    func debugBundleIncludesLLMPromptFile() async throws {
        let root = try temporaryDirectory()
        let diagnostics = try await Diagnostics.install(
            .init(
                serviceName: "maohuoban",
                environment: "test",
                storageDirectory: root.appendingPathComponent("segments")
            )
        )

        await diagnostics.error("checkout request failed")
        let bundle = try await diagnostics.exportDebugBundle(to: root.appendingPathComponent("bundle"))
        let prompt = try String(contentsOf: bundle.promptURL, encoding: .utf8)

        #expect(prompt.contains("maohuoban.diagnostics.prompt.v1"))
        #expect(prompt.contains("checkout request failed"))
    }

    @Test("诊断包会写入校验字段和归档文件")
    func debugBundleIncludesChecksumsAndArchive() async throws {
        let root = try temporaryDirectory()
        let diagnostics = try await Diagnostics.install(
            .init(
                serviceName: "maohuoban",
                environment: "test",
                storageDirectory: root.appendingPathComponent("segments")
            )
        )

        await diagnostics.error("archive input")
        let bundle = try await diagnostics.exportDebugBundle(to: root.appendingPathComponent("bundle"))
        let manifestData = try Data(contentsOf: bundle.manifestURL)
        let manifest = try #require(
            JSONSerialization.jsonObject(with: manifestData) as? [String: Any]
        )

        #expect((manifest["timelineSHA256"] as? String)?.count == 64)
        #expect((manifest["promptSHA256"] as? String)?.count == 64)
        #expect((manifest["indexSHA256"] as? String)?.count == 64)
        #expect(manifest["indexPath"] as? String == "index.json")
        #expect(manifest["archivePath"] as? String == "archive.tar")
        #expect(manifest["createdAtLocal"] is String)
        let manifestTimeBasis = try #require(manifest["timeBasis"] as? [String: Any])
        #expect(manifestTimeBasis["eventTimestamps"] as? String == "utc_rfc3339")
        #expect(manifestTimeBasis["localTimezone"] is String)
        #expect(FileManager.default.fileExists(atPath: bundle.archiveURL.path))
        #expect(FileManager.default.fileExists(atPath: bundle.indexURL.path))

        let indexData = try Data(contentsOf: bundle.indexURL)
        let index = String(data: indexData, encoding: .utf8) ?? ""
        #expect(index.contains("\"schema\":\"maohuoban.diagnostics.index.v1\""))
        #expect(index.contains("\"recommended_read_order\""))
        #expect(index.contains("\"prompt.md\""))
        #expect(index.contains("\"timeline.jsonl\""))
        let indexJson = try #require(
            JSONSerialization.jsonObject(with: indexData) as? [String: Any]
        )
        let indexTimeBasis = try #require(indexJson["time_basis"] as? [String: Any])
        #expect(indexTimeBasis["event_timestamps"] as? String == "utc_rfc3339")
        #expect(indexJson["first_event_at_local"] is String)
        #expect(indexJson["latest_event_at_local"] is String)

        let archive = try Data(contentsOf: bundle.archiveURL)
        let entries = try tarEntries(from: archive)
        let manifestArchiveData = try Data(contentsOf: bundle.manifestURL)
        let indexArchiveData = try Data(contentsOf: bundle.indexURL)
        let timelineArchiveData = try Data(contentsOf: bundle.timelineURL)
        let promptArchiveData = try Data(contentsOf: bundle.promptURL)
        #expect(entries["manifest.json"] == manifestArchiveData)
        #expect(entries["index.json"] == indexArchiveData)
        #expect(entries["timeline.jsonl"] == timelineArchiveData)
        #expect(entries["prompt.md"] == promptArchiveData)
    }

    @Test("LLM Prompt 导出会包含 schema 和时间线摘要")
    func exportsLLMPrompt() async throws {
        let root = try temporaryDirectory()
        let diagnostics = try await Diagnostics.install(
            .init(
                serviceName: "maohuoban",
                environment: "test",
                storageDirectory: root.appendingPathComponent("segments")
            )
        )

        await diagnostics.error("request timeout")
        let prompt = try await diagnostics.exportLLMPrompt(title: "分析这个 bug")

        #expect(prompt.contains("maohuoban.diagnostics.prompt.v1"))
        #expect(prompt.contains("分析这个 bug"))
        #expect(prompt.contains("request timeout"))
    }
}
