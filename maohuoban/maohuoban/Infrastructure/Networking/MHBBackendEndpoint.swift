import Foundation

// MHBBackendEndpoint 后端接口地址配置
// 核心职责：
// - 固定本地开发联调默认后端地址
// - 为模拟器和真机共用同一个局域网入口
enum MHBBackendEndpoint {
    static var localDevelopmentBaseURL: URL {
        localDevelopmentBaseURL(
            environment: ProcessInfo.processInfo.environment,
            arguments: ProcessInfo.processInfo.arguments,
            userDefaultsURLString: UserDefaults.standard.string(forKey: "MHB_BACKEND_BASE_URL")
        )
    }

    static func localDevelopmentBaseURL(
        environment: [String: String],
        arguments: [String],
        userDefaultsURLString: String?
    ) -> URL {
        if let overrideURL = launchArgumentValue(named: "-MHB_BACKEND_BASE_URL", in: arguments),
           let url = URL(string: overrideURL) {
            return url
        }
        if let overrideURL = environment["MHB_BACKEND_BASE_URL"],
           let url = URL(string: overrideURL) {
            return url
        }
        if let overrideURL = userDefaultsURLString,
           let url = URL(string: overrideURL) {
            return url
        }
        return URL(string: "http://192.168.2.2:8080")!
    }

    static func resolve(_ urlString: String) -> URL? {
        guard let url = URL(string: urlString) else {
            return nil
        }
        if url.scheme != nil {
            return url
        }
        return URL(string: urlString, relativeTo: localDevelopmentBaseURL)?.absoluteURL
    }

    private static func launchArgumentValue(named name: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: name) else {
            return nil
        }
        let valueIndex = arguments.index(after: index)
        guard arguments.indices.contains(valueIndex) else {
            return nil
        }
        return arguments[valueIndex]
    }
}
