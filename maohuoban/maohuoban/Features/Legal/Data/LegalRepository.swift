import Foundation

// LegalRepository 法务文档数据仓库协议
// 核心职责：
// - 定义登录页打开协议文档所需读取能力
// - 隔离后端 DTO 与展示层状态
protocol LegalRepository {
    func fetchDocument(kind: LegalDocumentKind) async throws(MHBAPIError) -> MHBAPIResponse<LegalDocument>
}

// DefaultLegalRepository 默认法务文档数据仓库
// 核心职责：
// - 使用 MHBHTTPClient 读取后端托管的协议正文
// - 将后端 DTO 映射为 LegalDocument
struct DefaultLegalRepository: LegalRepository {
    private let client: MHBHTTPClient

    init(client: MHBHTTPClient = MHBHTTPClient()) {
        self.client = client
    }

    func fetchDocument(kind: LegalDocumentKind) async throws(MHBAPIError) -> MHBAPIResponse<LegalDocument> {
        let response: MHBAPIResponse<LegalDocumentDTO> = try await client.get(
            path: "/api/v1/legal-documents/\(kind.rawValue)"
        )
        guard let dto = response.data else { throw MHBAPIError.invalidResponse }

        return MHBAPIResponse(
            success: response.success,
            code: response.code,
            message: response.message,
            data: try dto.toDomain()
        )
    }
}
