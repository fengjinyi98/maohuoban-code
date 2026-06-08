use crate::{CleanupPolicy, CleanupReport, DiagnosticEvent, DiagnosticsError};
use std::path::PathBuf;

/// `EventStore` 诊断事件存储接口
/// 核心职责：
/// - 隔离采集管线与落盘实现
/// - 支持测试、文件存储和未来数据库存储替换
pub trait EventStore: Send + Sync {
    /// `append` 写入单条诊断事件
    ///
    /// # Errors
    ///
    /// 当底层存储写入、序列化或锁状态异常时返回错误。
    fn append(&mut self, event: &DiagnosticEvent) -> Result<(), DiagnosticsError>;

    /// `flush` 刷新底层存储
    ///
    /// # Errors
    ///
    /// 当底层存储无法完成同步或持久化时返回错误。
    fn flush(&mut self) -> Result<(), DiagnosticsError>;

    /// `read_all` 读取全部诊断事件
    ///
    /// # Errors
    ///
    /// 当底层存储读取或反序列化失败时返回错误。
    fn read_all(&self) -> Result<Vec<DiagnosticEvent>, DiagnosticsError>;

    /// `cleanup` 执行清理策略
    ///
    /// # Errors
    ///
    /// 当底层存储读取文件元数据或删除数据失败时返回错误。
    fn cleanup(&mut self, policy: &CleanupPolicy) -> Result<CleanupReport, DiagnosticsError>;

    /// `export_index_path` 返回导出目录索引路径
    /// 核心职责：
    /// - 允许运行时持久记录 Debug Bundle 导出目录
    /// - 支持进程重启后继续清理过期导出包
    fn export_index_path(&self) -> Option<PathBuf> {
        None
    }
}
