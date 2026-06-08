import Foundation

// DiagnosticsRuntimeNetwork 运行时网络配置 API
// 核心职责：
// - 为 URLSessionConfiguration 注入诊断 URLProtocol
// - 保持产品网络采集接入点独立
extension DiagnosticsRuntime {
    public func instrumentedURLSessionConfiguration(
        _ base: URLSessionConfiguration = .default
    ) -> URLSessionConfiguration {
        let configuration = base
        var protocolClasses = configuration.protocolClasses ?? []
        protocolClasses.removeAll { $0 == DiagnosticsURLProtocol.self }
        protocolClasses.insert(DiagnosticsURLProtocol.self, at: 0)
        configuration.protocolClasses = protocolClasses
        return configuration
    }
}
