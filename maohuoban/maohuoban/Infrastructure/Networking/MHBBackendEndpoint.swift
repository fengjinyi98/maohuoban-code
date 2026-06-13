import Foundation

// MHBBackendEndpoint 后端接口地址配置
// 核心职责：
// - 固定本地开发联调默认后端地址
// - 为模拟器和真机共用同一个局域网入口
enum MHBBackendEndpoint {
    static var localDevelopmentBaseURL: URL {
        if let overrideURL = ProcessInfo.processInfo.environment["MHB_BACKEND_BASE_URL"],
           let url = URL(string: overrideURL) {
            return url
        }
        if let overrideURL = UserDefaults.standard.string(forKey: "MHB_BACKEND_BASE_URL"),
           let url = URL(string: overrideURL) {
            return url
        }
        return URL(string: "http://192.168.2.2:8080")!
    }
}
