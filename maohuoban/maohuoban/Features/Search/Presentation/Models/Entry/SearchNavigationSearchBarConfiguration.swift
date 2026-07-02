import Foundation

// SearchNavigationSearchBarConfiguration 导航搜索栏配置
// 核心职责：
// - 将搜索入口上下文转换为 UIKit 搜索栏展示配置
// - 保持系统搜索栏文案由入口上下文统一派生
struct SearchNavigationSearchBarConfiguration: Equatable {
    let prompt: String

    init(context: SearchEntryContext) {
        self.prompt = context.searchPrompt
    }
}
