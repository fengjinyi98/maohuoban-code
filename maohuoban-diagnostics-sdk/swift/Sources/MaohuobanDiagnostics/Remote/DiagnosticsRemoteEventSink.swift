import Foundation

// DiagnosticsRemoteEventSink 远端诊断事件镜像发送器
// 核心职责：
// - 将本地已采集事件异步回流到开发机 collector
// - 使用独立 URLSession 避免诊断请求再次触发全局网络采集
actor DiagnosticsRemoteEventSink {
    private let configuration: DiagnosticsRemoteMirrorConfiguration
    private let session: URLSession

    init(configuration: DiagnosticsRemoteMirrorConfiguration) {
        self.configuration = configuration
        let sessionConfiguration = URLSessionConfiguration.ephemeral
        sessionConfiguration.protocolClasses = []
        sessionConfiguration.timeoutIntervalForRequest = configuration.timeoutSeconds
        sessionConfiguration.timeoutIntervalForResource = configuration.timeoutSeconds
        session = URLSession(configuration: sessionConfiguration)
    }

    func append(_ event: DiagnosticEvent) async -> DiagnosticsRemoteMirrorResult {
        await appendBatch([event])
    }

    func appendBatch(_ events: [DiagnosticEvent]) async -> DiagnosticsRemoteMirrorResult {
        guard !events.isEmpty else {
            return .empty
        }
        var sentEventCount = 0
        var droppedEventCount = 0
        var lastError = ""
        do {
            let payloads = try Self.makeBatchPayloads(for: events, configuration: configuration)
            for payload in payloads {
                do {
                    let (_, response) = try await session.data(for: payload.request)
                    guard let httpResponse = response as? HTTPURLResponse else {
                        droppedEventCount += payload.eventCount
                        lastError = "remote mirror response was not HTTP"
                        continue
                    }
                    guard (200..<300).contains(httpResponse.statusCode) else {
                        droppedEventCount += payload.eventCount
                        lastError = "remote mirror HTTP \(httpResponse.statusCode)"
                        continue
                    }
                    sentEventCount += payload.eventCount
                } catch {
                    droppedEventCount += payload.eventCount
                    lastError = String(describing: error)
                }
            }
        } catch {
            droppedEventCount = events.count
            lastError = String(describing: error)
        }
        return DiagnosticsRemoteMirrorResult(
            sentEventCount: sentEventCount,
            droppedEventCount: droppedEventCount,
            lastError: lastError
        )
    }

    static func makeRequest(
        for event: DiagnosticEvent,
        configuration: DiagnosticsRemoteMirrorConfiguration
    ) throws -> URLRequest {
        var request = URLRequest(url: configuration.endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = configuration.timeoutSeconds
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        for (field, value) in configuration.headers {
            request.setValue(value, forHTTPHeaderField: field)
        }
        request.httpBody = try JSONEncoder.maohuobanDiagnostics.encode(event)
        return request
    }

    static func makeBatchRequest(
        for events: [DiagnosticEvent],
        configuration: DiagnosticsRemoteMirrorConfiguration
    ) throws -> URLRequest {
        try makeRequest(for: events, configuration: configuration)
    }

    static func makeBatchRequests(
        for events: [DiagnosticEvent],
        configuration: DiagnosticsRemoteMirrorConfiguration
    ) throws -> [URLRequest] {
        try makeBatchPayloads(for: events, configuration: configuration).map(\.request)
    }

    private static func makeBatchPayloads(
        for events: [DiagnosticEvent],
        configuration: DiagnosticsRemoteMirrorConfiguration
    ) throws -> [DiagnosticsRemoteMirrorPayload] {
        var payloads: [DiagnosticsRemoteMirrorPayload] = []
        var current: [DiagnosticEvent] = []

        for event in events {
            let candidate = current + [event]
            if current.isEmpty || shouldUseCandidate(candidate, configuration: configuration) {
                current = candidate
            } else {
                payloads.append(
                    DiagnosticsRemoteMirrorPayload(
                        eventCount: current.count,
                        request: try makeRequest(for: current, configuration: configuration)
                    )
                )
                current = [event]
            }
        }
        if !current.isEmpty {
            payloads.append(
                DiagnosticsRemoteMirrorPayload(
                    eventCount: current.count,
                    request: try makeRequest(for: current, configuration: configuration)
                )
            )
        }
        return payloads
    }

    private static func shouldUseCandidate(
        _ events: [DiagnosticEvent],
        configuration: DiagnosticsRemoteMirrorConfiguration
    ) -> Bool {
        guard events.count <= configuration.maxBatchEvents else {
            return false
        }
        guard let body = try? JSONEncoder.maohuobanDiagnostics.encode(events) else {
            return false
        }
        return body.count <= configuration.maxBatchBytes
    }

    private static func makeRequest(
        for events: [DiagnosticEvent],
        configuration: DiagnosticsRemoteMirrorConfiguration
    ) throws -> URLRequest {
        var request = URLRequest(url: configuration.endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = configuration.timeoutSeconds
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        for (field, value) in configuration.headers {
            request.setValue(value, forHTTPHeaderField: field)
        }
        request.httpBody = try JSONEncoder.maohuobanDiagnostics.encode(events)
        return request
    }
}

// DiagnosticsRemoteMirrorResult 远端镜像发送结果
// 核心职责：
// - 汇总本轮成功和失败事件数量
// - 为运行时健康快照提供最近一次远端失败原因
struct DiagnosticsRemoteMirrorResult: Sendable {
    static let empty = DiagnosticsRemoteMirrorResult(
        sentEventCount: 0,
        droppedEventCount: 0,
        lastError: ""
    )

    let sentEventCount: Int
    let droppedEventCount: Int
    let lastError: String
}

private struct DiagnosticsRemoteMirrorPayload {
    let eventCount: Int
    let request: URLRequest
}
