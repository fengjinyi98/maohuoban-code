//! `maohuoban_diagnostics` 诊断 SDK Rust 核心库
//!
//! 核心职责：
//! - 承载跨平台诊断事件、日志、性能、网络与清理策略的 Rust 实现
//! - 为 Swift SDK、命令行工具和本地 Collector 提供稳定的核心能力

/// `sdk_version` 返回当前诊断 SDK 版本
/// 核心职责：
/// - 暴露 crate 编译期版本
/// - 为诊断包和跨语言绑定提供版本标识
#[must_use]
pub fn sdk_version() -> &'static str {
    env!("CARGO_PKG_VERSION")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn sdk_version_matches_package_version() {
        assert_eq!(sdk_version(), env!("CARGO_PKG_VERSION"));
    }
}
