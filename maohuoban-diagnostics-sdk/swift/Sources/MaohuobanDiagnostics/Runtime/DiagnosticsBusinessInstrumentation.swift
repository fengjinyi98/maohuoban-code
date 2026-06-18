import Foundation

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
