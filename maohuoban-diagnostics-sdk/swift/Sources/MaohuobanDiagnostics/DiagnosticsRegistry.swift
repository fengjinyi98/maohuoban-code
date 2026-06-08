import Foundation

// DiagnosticsRegistry 全局运行时注册表
// 核心职责：
// - 串行化 SDK 安装与读取
// - 避免全局可变状态直接暴露给调用方
actor DiagnosticsRegistry {
    private var runtime: DiagnosticsRuntime?

    func install(_ configuration: DiagnosticsConfiguration) throws -> DiagnosticsRuntime {
        let runtime = try DiagnosticsRuntime(configuration: configuration)
        self.runtime = runtime
        DiagnosticsURLProtocol.runtime = runtime
        URLProtocol.registerClass(DiagnosticsURLProtocol.self)
        return runtime
    }

    func current() -> DiagnosticsRuntime? {
        runtime
    }
}
