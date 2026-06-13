use std::sync::Arc;

use maohuoban_legal_domain::legal::{LegalDocument, LegalDocumentKind, LegalError, LegalResult};

use super::LegalDocumentRepository;

/// `LegalDocumentService` 法务文档读取用例
/// 核心职责：
/// - 校验客户端请求的文档类型
/// - 从仓储读取运营托管的已发布文档
pub struct LegalDocumentService {
    repository: Arc<dyn LegalDocumentRepository>,
}

impl LegalDocumentService {
    #[must_use]
    pub fn new(repository: Arc<dyn LegalDocumentRepository>) -> Self {
        Self { repository }
    }

    /// # Errors
    /// - 当文档类型未知、文档不存在或仓储读取失败时返回 `LegalError`
    pub async fn get_document(&self, kind: &str) -> LegalResult<LegalDocument> {
        let Some(kind) = LegalDocumentKind::parse(kind) else {
            return Err(LegalError::DocumentNotFound);
        };
        self.repository
            .find_document(kind)
            .await?
            .ok_or(LegalError::DocumentNotFound)
    }
}
