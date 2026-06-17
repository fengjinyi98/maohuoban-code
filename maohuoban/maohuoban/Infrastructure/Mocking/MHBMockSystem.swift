import Foundation

// MHBMockSystem Mock 数据系统配置
// 核心职责：
// - 统一读取 Mock 数据开关
// - 为各业务域提供独立场景选择入口
enum MHBMockSystem {
    nonisolated static func isEnabled(processInfo: ProcessInfo = .processInfo) -> Bool {
        #if DEBUG
        let isDebugBuild = true
        #else
        let isDebugBuild = false
        #endif

        return isEnabled(
            arguments: processInfo.arguments,
            environment: processInfo.environment,
            isDebugBuild: isDebugBuild
        )
    }

    nonisolated static func isEnabled(
        arguments: [String],
        environment: [String: String],
        isDebugBuild _: Bool
    ) -> Bool {
        if arguments.contains("--use-backend-data") {
            return false
        }
        if arguments.contains("--use-mock-data") {
            return true
        }
        if let environmentValue = environment["MHB_USE_MOCK_DATA"],
           let isEnabled = parseBoolean(environmentValue) {
            return isEnabled
        }

        return false
    }

    nonisolated static func scenario(
        namespace: String,
        default defaultValue: String,
        processInfo: ProcessInfo = .processInfo
    ) -> String {
        let normalizedNamespace = namespace
            .uppercased()
            .replacingOccurrences(of: "-", with: "_")
        let namespacedEnvironmentKey = "MHB_\(normalizedNamespace)_MOCK_SCENARIO"
        if let namespacedValue = normalizedValue(processInfo.environment[namespacedEnvironmentKey]) {
            return namespacedValue
        }
        if let globalValue = normalizedValue(processInfo.environment["MHB_MOCK_SCENARIO"]) {
            return globalValue
        }

        let namespacedArgumentPrefix = "--\(namespace)-mock-scenario="
        if let namespacedArgument = argumentValue(
            in: processInfo.arguments,
            prefix: namespacedArgumentPrefix
        ) {
            return namespacedArgument
        }
        if let globalArgument = argumentValue(
            in: processInfo.arguments,
            prefix: "--mock-scenario="
        ) {
            return globalArgument
        }

        return defaultValue
    }

    private nonisolated static func parseBoolean(_ value: String) -> Bool? {
        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "1", "true", "yes", "on", "enabled":
            true
        case "0", "false", "no", "off", "disabled":
            false
        default:
            nil
        }
    }

    private nonisolated static func normalizedValue(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }

    private nonisolated static func argumentValue(in arguments: [String], prefix: String) -> String? {
        arguments
            .first { $0.hasPrefix(prefix) }
            .flatMap { normalizedValue(String($0.dropFirst(prefix.count))) }
    }
}
