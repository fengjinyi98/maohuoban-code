import Foundation

// SettingsLogoutSheetMessageBuilder 退出登录文案构建器
// 核心职责：
// - 统一设置页退出登录确认文案
// - 使用当前账号名称生成可测试展示文本
enum SettingsLogoutSheetMessageBuilder {
    nonisolated static func confirmationMessage(username: String) -> String {
        "确认退出该账号 @\(username) 吗？"
    }
}
