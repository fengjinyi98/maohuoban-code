import Foundation

// DiagnosticsRuntimeStorage 运行时存储与导出 API
// 核心职责：
// - 暴露刷新、读取和清理诊断事件的句柄级入口
// - 编排 Debug Bundle 和 LLM Prompt 导出
extension DiagnosticsRuntime {
    public func flush() async throws {
        try await eventWriter.flush()
        try await store.flush()
    }

    public func readEvents() async throws -> [DiagnosticEvent] {
        try await eventWriter.readAll()
    }

    public func cleanup() async throws -> CleanupReport {
        try await cleanup(policy: configuration.cleanup)
    }

    // cleanup 使用指定策略清理诊断存储
    // 核心职责：
    // - 支持调用方执行一次性全量清理
    // - 复用段文件与导出包清理统计
    public func cleanup(policy: CleanupPolicy) async throws -> CleanupReport {
        try await eventWriter.flush()
        var report = try await store.cleanup(policy)
        let exportReport = try exportRegistry.cleanup(policy: policy)
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
