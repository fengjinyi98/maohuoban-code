import Foundation

// MaohuobanDiagnosticsLaunchMode 诊断启动模式
// 核心职责：
// - 解析 app 启动参数中的诊断维护命令
// - 将普通启动与报告清理启动路径分离
enum MaohuobanDiagnosticsLaunchMode: Equatable {
    case normal
    case purgeReports

    private static let purgeArgument = "--maohuoban-diagnostics-purge"
    private static let purgeEnvironmentKey = "MAOHUOBAN_DIAGNOSTICS_PURGE"

    init(
        arguments: [String],
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        if arguments.contains(Self.purgeArgument) || environment[Self.purgeEnvironmentKey] == "1" {
            self = .purgeReports
        } else {
            self = .normal
        }
    }
}
