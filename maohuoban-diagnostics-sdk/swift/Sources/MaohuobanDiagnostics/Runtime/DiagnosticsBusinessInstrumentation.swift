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
    // instrumentStoreCommand 记录 Store 命令生命周期
    // 核心职责：
    // - 标准化 Store 命令开始、成功、失败事件
    // - 将耗时和可聚合错误类型写入统一 timeline
    @discardableResult
    @MainActor
    public static func instrumentStoreCommand<Value: Sendable>(
        name: String,
        store: String,
        command: String,
        metadata: DiagnosticProperties = [:],
        operation: () async throws -> Value
    ) async throws -> Value {
        let startedAt = Date()
        await record(
            businessEvent(
                name: "\(name).started",
                metadata: metadata,
                extra: [
                    "event_type": .string("store_command"),
                    "store": .string(store),
                    "command": .string(command)
                ]
            )
        )
        do {
            let value = try await operation()
            await record(
                businessEvent(
                    name: "\(name).succeeded",
                    metadata: metadata,
                    extra: [
                        "event_type": .string("store_command"),
                        "store": .string(store),
                        "command": .string(command),
                        "result": .string("succeeded"),
                        "duration_ms": .string(durationMilliseconds(since: startedAt))
                    ]
                )
            )
            return value
        } catch {
            await record(
                businessEvent(
                    name: "\(name).failed",
                    severity: .error,
                    metadata: metadata,
                    extra: [
                        "event_type": .string("store_command"),
                        "store": .string(store),
                        "command": .string(command),
                        "result": .string("failed"),
                        "duration_ms": .string(durationMilliseconds(since: startedAt)),
                        "error_kind": .string(String(reflecting: type(of: error)))
                    ]
                )
            )
            throw error
        }
    }

    // recordStoreStateTransition 记录 Store 状态转换
    // 核心职责：
    // - 只记录枚举态名称和结果
    // - 避免将用户输入或展示文案写入诊断事件
    @MainActor
    public static func recordStoreStateTransition(
        store: String,
        command: String,
        fromState: String,
        toState: String,
        result: String,
        visibleErrorKind: String? = nil,
        metadata: DiagnosticProperties = [:]
    ) async {
        var extra: DiagnosticProperties = [
            "event_type": .string("store_state_transition"),
            "store": .string(store),
            "command": .string(command),
            "from_state": .string(fromState),
            "to_state": .string(toState),
            "result": .string(result)
        ]
        if let visibleErrorKind {
            extra["visible_error_kind"] = .string(visibleErrorKind)
        }
        await record(businessEvent(name: "store.state.changed", metadata: metadata, extra: extra))
    }

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

    // recordFormFieldFocused 记录表单字段聚焦
    // 核心职责：
    // - 捕获输入边界事件
    // - 只记录 form、field 和 screen_name
    @MainActor
    public static func recordFormFieldFocused(
        form: String,
        field: String,
        screenName: String,
        metadata: DiagnosticProperties = [:]
    ) async {
        await record(
            businessEvent(
                name: "form.field.focused",
                metadata: metadata,
                extra: formBaseMetadata(form: form, field: field, screenName: screenName)
            )
        )
    }

    // recordFormFieldBlurred 记录表单字段失焦
    // 核心职责：
    // - 记录长度桶、空值和校验结果
    // - 避免记录字段原文
    @MainActor
    public static func recordFormFieldBlurred(
        form: String,
        field: String,
        screenName: String,
        valueLength: Int,
        valid: Bool,
        metadata: DiagnosticProperties = [:]
    ) async {
        var extra = formBaseMetadata(form: form, field: field, screenName: screenName)
        extra["empty"] = .bool(valueLength == 0)
        extra["length_bucket"] = .string(lengthBucket(for: valueLength))
        extra["valid"] = .bool(valid)
        await record(businessEvent(name: "form.field.blurred", metadata: metadata, extra: extra))
    }

    // recordFormValidationFailed 记录表单校验失败
    // 核心职责：
    // - 记录规则和错误类别
    // - 支持按字段聚合表单问题
    @MainActor
    public static func recordFormValidationFailed(
        form: String,
        field: String,
        screenName: String,
        rule: String,
        errorKind: String,
        metadata: DiagnosticProperties = [:]
    ) async {
        var extra = formBaseMetadata(form: form, field: field, screenName: screenName)
        extra["rule"] = .string(rule)
        extra["error_kind"] = .string(errorKind)
        await record(
            businessEvent(
                name: "form.validation.failed",
                severity: .warn,
                metadata: metadata,
                extra: extra
            )
        )
    }

    // recordScreenReady 记录页面 ready 性能事件
    // 核心职责：
    // - 捕获数据 ready、可交互和首屏数量
    // - 为页面首屏体验建立统一性能字段
    @MainActor
    public static func recordScreenReady(
        screenName: String,
        dataReadyMs: Int,
        interactiveMs: Int? = nil,
        visibleItemCount: Int? = nil,
        metadata: DiagnosticProperties = [:]
    ) async {
        var extra = metadata
        extra["screen_name"] = .string(screenName)
        extra["screen_data_ready_ms"] = .string("\(dataReadyMs)")
        if let interactiveMs {
            extra["screen_interactive_ms"] = .string("\(interactiveMs)")
        }
        if let visibleItemCount {
            extra["visible_item_count"] = .string("\(visibleItemCount)")
        }
        await record(
            DiagnosticEvent(kind: .performance, severity: .info, message: "screen.performance.ready", metadata: extra)
        )
    }
}

private func businessEvent(
    name: String,
    severity: DiagnosticSeverity = .info,
    metadata: DiagnosticProperties,
    extra: DiagnosticProperties
) -> DiagnosticEvent {
    DiagnosticEvent(
        kind: .analytics,
        severity: severity,
        message: name,
        metadata: metadata.merging(extra) { _, new in new }
    )
}

private func durationMilliseconds(since date: Date) -> String {
    "\(max(0, Int(Date().timeIntervalSince(date) * 1_000)))"
}

private func formBaseMetadata(
    form: String,
    field: String,
    screenName: String
) -> DiagnosticProperties {
    [
        "form": .string(form),
        "field": .string(field),
        "screen_name": .string(screenName)
    ]
}

private func lengthBucket(for valueLength: Int) -> String {
    switch valueLength {
    case 0:
        "empty"
    case 1...8:
        "short"
    case 9...32:
        "medium"
    case 33...128:
        "long"
    default:
        "very_long"
    }
}
