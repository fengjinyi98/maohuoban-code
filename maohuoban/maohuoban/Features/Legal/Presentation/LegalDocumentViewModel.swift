import Foundation
import Observation

// LegalDocumentViewModel 法务文档展示状态模型
// 核心职责：
// - 管理协议文档加载状态、错误和后端 HTML 内容
// - 通过 Repository 暴露明确的异步加载入口
@MainActor
@Observable
final class LegalDocumentViewModel {
    let kind: LegalDocumentKind
    var document: LegalDocument?
    var isLoading = false
    var errorMessage: String?

    private let repository: LegalRepository

    init(
        kind: LegalDocumentKind,
        repository: LegalRepository = DefaultLegalRepository()
    ) {
        self.kind = kind
        self.repository = repository
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        do {
            let response = try await repository.fetchDocument(kind: kind)
            guard let document = response.data else { throw MHBAPIError.invalidResponse }
            self.document = document
        } catch let error as MHBAPIError {
            errorMessage = error.toastMessage
        } catch {
            errorMessage = "文档加载失败，请稍后再试"
        }

        isLoading = false
    }
}
