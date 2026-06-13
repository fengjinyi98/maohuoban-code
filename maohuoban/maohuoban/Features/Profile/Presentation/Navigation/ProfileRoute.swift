import Foundation

// ProfileRoute 我的 Tab 路由枚举
// 核心职责：
// - 定义"我的"Tab 内所有可 push 的页面路由
// - 关联值携带目标页面所需的最小参数
// - 后续随设置/账号功能迭代扩展 case
enum ProfileRoute: Hashable {
    /// 占位路由 — 后续替换为实际页面路由
    case placeholder
}
