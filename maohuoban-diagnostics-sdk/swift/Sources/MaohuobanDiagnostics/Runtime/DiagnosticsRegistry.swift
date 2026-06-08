import Foundation

// DiagnosticsRegistry 全局运行时注册表
// 核心职责：
// - 串行化 SDK 安装与读取
// - 避免全局可变状态直接暴露给调用方
actor DiagnosticsRegistry {
    private var runtime: DiagnosticsRuntime?
    private var isGlobalNetworkCaptureRegistered = false

    func install(_ configuration: DiagnosticsConfiguration) throws -> DiagnosticsRuntime {
        let runtime = try DiagnosticsRuntime(configuration: configuration)
        self.runtime = runtime
        DiagnosticsURLProtocol.runtime = runtime
        if configuration.networkCapture == .globalURLProtocol, !isGlobalNetworkCaptureRegistered {
            URLProtocol.registerClass(DiagnosticsURLProtocol.self)
            isGlobalNetworkCaptureRegistered = true
        }
        return runtime
    }

    func current() -> DiagnosticsRuntime? {
        runtime
    }

    func uninstall() {
        runtime = nil
        DiagnosticsURLProtocol.runtime = nil
        if isGlobalNetworkCaptureRegistered {
            URLProtocol.unregisterClass(DiagnosticsURLProtocol.self)
            isGlobalNetworkCaptureRegistered = false
        }
    }

    func globalNetworkCaptureRegistered() -> Bool {
        isGlobalNetworkCaptureRegistered
    }
}
