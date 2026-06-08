import Foundation

// DiagnosticsRuntimeStorage 运行时存储与导出 API
// 核心职责：
// - 暴露刷新、读取和清理诊断事件的句柄级入口
// - 编排 Debug Bundle 和 LLM Prompt 导出
extension DiagnosticsRuntime {
    public func flush() async throws {
        try await store.flush()
    }

    public func readEvents() async throws -> [DiagnosticEvent] {
        try await store.readAll()
    }

    public func cleanup() async throws -> CleanupReport {
        var report = try await store.cleanup(configuration.cleanup)
        let exportReport = try exportRegistry.cleanup(policy: configuration.cleanup)
        report.removedExports += exportReport.removedExports
        report.freedBytes += exportReport.freedBytes
        return report
    }

    public func exportDebugBundle(to outputDirectory: URL) async throws -> DebugBundle {
        let bundle = try DebugBundleExporter(outputDirectory: outputDirectory)
            .export(events: try await readEvents())
        try exportRegistry.register(bundle.directoryURL)
        return bundle
    }

    public func exportLLMPrompt(title: String, maxEvents: Int = 200) async throws -> String {
        LLMPromptExporter(title: title, maxEvents: maxEvents)
            .export(events: try await readEvents())
    }
}
