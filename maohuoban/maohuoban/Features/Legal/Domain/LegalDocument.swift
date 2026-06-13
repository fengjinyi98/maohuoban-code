import Foundation

// LegalDocumentKind 法务文档类型
// 核心职责：
// - 定义前端可请求的后端文档 kind
// - 为页面展示提供稳定身份和值
enum LegalDocumentKind: String, Decodable, Identifiable, Equatable {
    case userAgreement = "user_agreement"
    case privacyPolicy = "privacy_policy"

    var id: String { rawValue }

    var fallbackTitle: String {
        switch self {
        case .userAgreement:
            "用户服务协议"
        case .privacyPolicy:
            "用户隐私政策"
        }
    }
}

// LegalDocument 法务文档领域模型
// 核心职责：
// - 承接后端托管的协议标题、版本和 HTML 正文
// - 隔离展示层对后端 DTO 字段命名的依赖
struct LegalDocument: Decodable, Equatable {
    let kind: LegalDocumentKind
    let title: String
    let version: String
    let effectiveDate: String
    let publishedAt: String
    let updatedAt: String
    let html: String
}
