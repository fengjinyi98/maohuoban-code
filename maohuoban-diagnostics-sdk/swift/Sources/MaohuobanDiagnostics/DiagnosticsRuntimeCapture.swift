import Foundation

// DiagnosticsRuntimeCapture 运行时采集 API
// 核心职责：
// - 记录日志、面包屑、错误、网络和运行时快照
// - 统一执行上下文补齐、采集策略、隐私策略和存储写入
extension DiagnosticsRuntime {
    public func record(_ event: DiagnosticEvent) async {
        let contextualEvent = await context.apply(to: event)
        guard let capturedEvent = configuration.capture.apply(
            to: contextualEvent
                .metadata("service", configuration.serviceName)
                .metadata("environment", configuration.environment)
        ) else {
            return
        }
        let event = configuration.privacy.apply(to: capturedEvent)
        do {
            try await store.append(event)
        } catch {
            await storageHealth.recordDroppedEvent(error)
        }
    }

    public func log(_ severity: DiagnosticSeverity, _ message: String) async {
        await record(.log(severity, message))
    }

    public func breadcrumb(_ message: String, metadata: [String: String] = [:]) async {
        var event = DiagnosticEvent(kind: .breadcrumb, severity: .info, message: message)
        for (key, value) in metadata {
            event = event.metadata(key, value)
        }
        await record(event)
    }

    public func error(_ message: String, metadata: [String: String] = [:]) async {
        var event = DiagnosticEvent.error(message)
        for (key, value) in metadata {
            event = event.metadata(key, value)
        }
        await record(event)
    }

    public func captureError(_ error: Error, metadata: [String: String] = [:]) async {
        var event = DiagnosticEvent.error(error.localizedDescription)
        let nsError = error as NSError
        event = event
            .metadata("error", error.localizedDescription)
            .metadata("error_type", String(reflecting: type(of: error)))
            .metadata("error_domain", nsError.domain)
            .metadata("error_code", "\(nsError.code)")
            .metadata("error_description", nsError.localizedDescription)

        let underlyingErrors = underlyingErrorDescriptions(from: nsError)
        if !underlyingErrors.isEmpty {
            event = event.metadata("underlying_errors", underlyingErrors.joined(separator: " | "))
        }

        for (key, value) in metadata {
            event = event.metadata(key, value)
        }
        await record(event)
    }

    public func network(_ summary: NetworkSummary) async {
        await record(summary.event())
    }

    public func captureRuntimeSnapshot(metadata: [String: String] = [:]) async {
        let processInfo = ProcessInfo.processInfo
        let storageStatus = await storageHealth.snapshot()
        var event = DiagnosticEvent.performance("runtime snapshot")
            .metadata("process_id", "\(processInfo.processIdentifier)")
            .metadata("process_name", processInfo.processName)
            .metadata("os", processInfo.operatingSystemVersionString)
            .metadata("arch", runtimeArchitecture())
            .metadata("uptime_ms", "\(Int(Date().timeIntervalSince(startedAt) * 1_000))")
            .metadata("physical_memory_bytes", "\(processInfo.physicalMemory)")
        if storageStatus.droppedEventCount > 0 {
            event = event
                .metadata("dropped_event_count", "\(storageStatus.droppedEventCount)")
                .metadata("last_storage_error", storageStatus.lastStorageError)
        }
        for (key, value) in metadata {
            event = event.metadata(key, value)
        }
        await record(event)
    }
}

private func underlyingErrorDescriptions(from error: NSError) -> [String] {
    var descriptions: [String] = []
    var current = error.userInfo[NSUnderlyingErrorKey] as? NSError
    while let error = current {
        descriptions.append("\(error.domain):\(error.code): \(error.localizedDescription)")
        current = error.userInfo[NSUnderlyingErrorKey] as? NSError
    }
    return descriptions
}

private func runtimeArchitecture() -> String {
    #if arch(arm64)
    "arm64"
    #elseif arch(x86_64)
    "x86_64"
    #elseif arch(arm)
    "arm"
    #elseif arch(i386)
    "i386"
    #else
    "unknown"
    #endif
}
