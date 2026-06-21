import Foundation

// MessageRoute 消息页导航路由
// 核心职责：
// - 描述消息 Tab 内部系统导航目标
// - 为导航栏与内容流 tabs 实验提供稳定 Hashable 值
enum MessageRoute: Hashable {
    case tabsExperiment
}
