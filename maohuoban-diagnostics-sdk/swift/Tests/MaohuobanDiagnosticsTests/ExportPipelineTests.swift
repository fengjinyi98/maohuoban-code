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
                storageDirectory: root.appending(path: "segments")
            )
        )

        await diagnostics.error("checkout request failed")
        let bundle = try await diagnostics.exportDebugBundle(to: root.appending(path: "bundle"))
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
                storageDirectory: root.appending(path: "segments")
            )
        )

        await diagnostics.error("archive input")
        let bundle = try await diagnostics.exportDebugBundle(to: root.appending(path: "bundle"))
        let manifestData = try Data(contentsOf: bundle.manifestURL)
        let manifest = try #require(
            JSONSerialization.jsonObject(with: manifestData) as? [String: String]
        )

        #expect(manifest["timelineSHA256"]?.count == 64)
        #expect(manifest["promptSHA256"]?.count == 64)
        #expect(manifest["archivePath"] == "archive.tar")
        #expect(FileManager.default.fileExists(atPath: bundle.archiveURL.path))

        let archive = try Data(contentsOf: bundle.archiveURL)
        let entries = try tarEntries(from: archive)
        let manifestArchiveData = try Data(contentsOf: bundle.manifestURL)
        let timelineArchiveData = try Data(contentsOf: bundle.timelineURL)
        let promptArchiveData = try Data(contentsOf: bundle.promptURL)
        #expect(entries["manifest.json"] == manifestArchiveData)
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
                storageDirectory: root.appending(path: "segments")
            )
        )

        await diagnostics.error("request timeout")
        let prompt = try await diagnostics.exportLLMPrompt(title: "分析这个 bug")

        #expect(prompt.contains("maohuoban.diagnostics.prompt.v1"))
        #expect(prompt.contains("分析这个 bug"))
        #expect(prompt.contains("request timeout"))
    }
}
