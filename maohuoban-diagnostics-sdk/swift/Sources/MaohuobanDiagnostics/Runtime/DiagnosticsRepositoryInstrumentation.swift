import Foundation

// DiagnosticsRepositorySource Repository 数据来源
// 核心职责：
// - 统一 Repository 观测中的 source 字段
// - 避免业务层散写字符串导致聚合困难
public enum DiagnosticsRepositorySource: String, Sendable {
    case network
    case cache
    case memory
}

// DiagnosticsRepositoryResult Repository 观测结果包装
// 核心职责：
// - 携带 Repository 原始返回值
// - 为统一响应摘要提供 item_count 和 api_code
public struct DiagnosticsRepositoryResult<Value>: @unchecked Sendable {
    public var value: Value
    public var itemCount: Int?
    public var apiCode: String?
    public var hasData: Bool

    public init(
        value: Value,
        itemCount: Int? = nil,
        apiCode: String? = nil,
        hasData: Bool = true
    ) {
        self.value = value
        self.itemCount = itemCount
        self.apiCode = apiCode
        self.hasData = hasData
    }
}

extension Diagnostics {
    // instrumentRepositoryCall 记录 Repository 调用
    // 核心职责：
    // - 标准化 Repository 请求、响应和失败事件
    // - 为数据条数、api_code 和耗时提供统一字段
    @discardableResult
    public nonisolated(nonsending) static func instrumentRepositoryCall<Value>(
        name: String,
        repository: String,
        source: DiagnosticsRepositorySource,
        metadata: DiagnosticProperties = [:],
        operation: () async throws -> DiagnosticsRepositoryResult<Value>
    ) async throws -> DiagnosticsRepositoryResult<Value> {
        let startedAt = Date()
        await record(
            businessEvent(
                name: "\(name).started",
                metadata: metadata,
                extra: [
                    "event_type": .string("repository_call"),
                    "repository": .string(repository),
                    "source": .string(source.rawValue)
                ]
            )
        )
        do {
            let result = try await operation()
            var extra: DiagnosticProperties = [
                "event_type": .string("repository_call"),
                "repository": .string(repository),
                "source": .string(source.rawValue),
                "result": .string("succeeded"),
                "has_data": .bool(result.hasData),
                "duration_ms": .string(durationMilliseconds(since: startedAt))
            ]
            if let itemCount = result.itemCount {
                extra["item_count"] = .string("\(itemCount)")
            }
            if let apiCode = result.apiCode {
                extra["api_code"] = .string(apiCode)
            }
            await record(
                businessEvent(
                    name: "\(name).succeeded",
                    metadata: metadata,
                    extra: extra
                )
            )
            return result
        } catch {
            await record(
                businessEvent(
                    name: "\(name).failed",
                    severity: .error,
                    metadata: metadata,
                    extra: [
                        "event_type": .string("repository_call"),
                        "repository": .string(repository),
                        "source": .string(source.rawValue),
                        "result": .string("failed"),
                        "duration_ms": .string(durationMilliseconds(since: startedAt)),
                        "error_kind": .string(String(reflecting: type(of: error)))
                    ]
                )
            )
            throw error
        }
    }
}
