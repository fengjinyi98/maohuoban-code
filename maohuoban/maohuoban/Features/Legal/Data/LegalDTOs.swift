import Foundation

// LegalDocumentDTO 法务文档响应 DTO
// 核心职责：
// - 解析后端 legal document JSON 载荷
// - 映射为前端 LegalDocument 领域模型
struct LegalDocumentDTO: Decodable {
    let kind: String
    let title: String
    let version: String
    let effectiveDate: String
    let publishedAt: String
    let updatedAt: String
    let html: String

    enum CodingKeys: String, CodingKey {
        case kind
        case title
        case version
        case effectiveDate = "effective_date"
        case publishedAt = "published_at"
        case updatedAt = "updated_at"
        case html
    }

    func toDomain() throws(MHBAPIError) -> LegalDocument {
        guard let documentKind = LegalDocumentKind(rawValue: kind) else {
            throw .decoding("未知法务文档类型")
        }

        return LegalDocument(
            kind: documentKind,
            title: title,
            version: version,
            effectiveDate: effectiveDate,
            publishedAt: publishedAt,
            updatedAt: updatedAt,
            html: html
        )
    }
}
