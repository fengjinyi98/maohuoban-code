use async_trait::async_trait;
use chrono::{DateTime, NaiveDate, Utc};
use maohuoban_legal_application::legal::LegalDocumentRepository;
use maohuoban_legal_domain::legal::{LegalDocument, LegalDocumentKind, LegalError, LegalResult};
use sqlx::{FromRow, PgPool};

/// `PostgresLegalDocumentRepository` `PostgreSQL` 法务文档仓储
/// 核心职责：
/// - 从 `legal_documents` 表读取运营托管内容
/// - 将数据库行转换为领域文档模型
#[derive(Debug, Clone)]
pub struct PostgresLegalDocumentRepository {
    pool: PgPool,
}

impl PostgresLegalDocumentRepository {
    #[must_use]
    pub const fn new(pool: PgPool) -> Self {
        Self { pool }
    }
}

#[async_trait]
impl LegalDocumentRepository for PostgresLegalDocumentRepository {
    async fn find_document(&self, kind: LegalDocumentKind) -> LegalResult<Option<LegalDocument>> {
        let row = sqlx::query_as::<_, LegalDocumentRow>(
            r"
            SELECT kind, title, version, effective_date, published_at, updated_at, html
            FROM legal_documents
            WHERE kind = $1 AND is_published = TRUE
            ",
        )
        .bind(kind.as_str())
        .fetch_optional(&self.pool)
        .await
        .map_err(|error| LegalError::Infrastructure(error.to_string()))?;

        row.map(TryInto::try_into).transpose()
    }
}

/// `LegalDocumentRow` 法务文档数据库行
/// 核心职责：
/// - 对齐 `legal_documents` 查询字段
/// - 隔离 `SQLx` 解码结构和领域结构
#[derive(Debug, FromRow)]
struct LegalDocumentRow {
    kind: String,
    title: String,
    version: String,
    effective_date: NaiveDate,
    published_at: DateTime<Utc>,
    updated_at: DateTime<Utc>,
    html: String,
}

impl TryFrom<LegalDocumentRow> for LegalDocument {
    type Error = LegalError;

    fn try_from(row: LegalDocumentRow) -> Result<Self, Self::Error> {
        let kind = LegalDocumentKind::parse(&row.kind).ok_or_else(|| {
            LegalError::Infrastructure(format!("unknown legal document kind: {}", row.kind))
        })?;

        Ok(Self {
            kind,
            title: row.title,
            version: row.version,
            effective_date: row.effective_date,
            published_at: row.published_at,
            updated_at: row.updated_at,
            html: row.html,
        })
    }
}
