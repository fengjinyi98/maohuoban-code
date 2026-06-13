use async_trait::async_trait;
use maohuoban_home_domain::home::HomeDashboardSnapshot;
use thiserror::Error;

pub type HomeResult<T> = Result<T, HomeError>;

/// HomeError 首页应用错误
/// 核心职责：
/// - 汇总首页聚合读取失败原因
/// - 隔离 HTTP 层和基础设施错误细节
#[derive(Debug, Error)]
pub enum HomeError {
    #[error("home dashboard is unavailable: {0}")]
    Infrastructure(String),
}

/// HomeDashboardProvider 首页快照读取端口
/// 核心职责：
/// - 为首页聚合服务提供当前身份下的快照
/// - 让内存种子、PostgreSQL 和后续推荐服务实现保持可替换
#[async_trait]
pub trait HomeDashboardProvider: Send + Sync {
    async fn get_dashboard_snapshot(&self) -> HomeResult<HomeDashboardSnapshot>;
}

/// HomeDashboardService 首页聚合服务
/// 核心职责：
/// - 编排首页快照读取
/// - 保持 HTTP handler 只依赖应用层用例
pub struct HomeDashboardService {
    provider: Box<dyn HomeDashboardProvider>,
}

impl HomeDashboardService {
    #[must_use]
    pub fn new(provider: Box<dyn HomeDashboardProvider>) -> Self {
        Self { provider }
    }

    pub async fn get_dashboard_snapshot(&self) -> HomeResult<HomeDashboardSnapshot> {
        self.provider.get_dashboard_snapshot().await
    }
}
