import Foundation

// MHBAPIError 网络与业务错误
// 核心职责：
// - 统一表达 HTTP、业务 code/message、解码和网络错误
// - 向 ViewModel 提供可展示给 Toast 的 message
enum MHBAPIError: LocalizedError, Equatable {
    case business(code: String, message: String, statusCode: Int)
    case invalidResponse
    case transport(String)
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .business(_, let message, _):
            message
        case .invalidResponse:
            "服务响应异常，请稍后再试"
        case .transport:
            "网络连接失败，请检查网络后重试"
        case .decoding:
            "服务数据解析失败，请稍后再试"
        }
    }

    var toastMessage: String {
        errorDescription ?? "服务暂时不可用，请稍后再试"
    }

    var isAuthenticationInvalidation: Bool {
        guard case .business(let code, _, let statusCode) = self else {
            return false
        }
        return statusCode == 401 && [
            "auth.session_expired",
            "auth.session_revoked",
            "auth.token_invalid",
            "auth.account_disabled"
        ].contains(code)
    }
}

extension Notification.Name {
    // mhbAuthenticationInvalidated 认证失效通知
    // 核心职责：
    // - 让网络层把服务端认证失效事件交给 App 根状态处理
    // - 避免业务页面各自实现回登录逻辑
    static let mhbAuthenticationInvalidated = Notification.Name("MHBAuthenticationInvalidated")
}
