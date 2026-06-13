use async_trait::async_trait;
use maohuoban_legal_domain::legal::{LegalDocument, LegalDocumentKind, LegalResult};

/// `LegalDocumentRepository` 法务文档仓储端口
/// 核心职责：
/// - 按文档类型读取已发布正文
/// - 让应用层不依赖 `PostgreSQL` 实现细节
#[async_trait]
pub trait LegalDocumentRepository: Send + Sync {
    async fn find_document(
        &self,
        kind: LegalDocumentKind,
    ) -> LegalResult<Option<LegalDocument>>;
}
