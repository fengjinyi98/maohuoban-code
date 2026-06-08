/// `sdk_version` 返回当前诊断 SDK 版本
/// 核心职责：
/// - 暴露 crate 编译期版本
/// - 为诊断包和跨语言绑定提供版本标识
#[must_use]
pub fn sdk_version() -> &'static str {
    env!("CARGO_PKG_VERSION")
}
