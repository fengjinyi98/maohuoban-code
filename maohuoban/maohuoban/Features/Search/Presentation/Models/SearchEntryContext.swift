import Foundation

// SearchEntryContext 搜索入口上下文
// 核心职责：
// - 区分搜索页来自宠物世界或同城
// - 为原生搜索框提示和热搜标题提供来源文案
enum SearchEntryContext: Hashable {
    case petWorld
    case sameCity(city: String)

    var searchPrompt: String {
        switch self {
        case .petWorld:
            "搜索宠物经验、话题和动态"
        case .sameCity(let city):
            "搜索\(city)同城 柯基 拼单"
        }
    }

    var hotSectionTitle: String {
        switch self {
        case .petWorld:
            "宠物世界热搜"
        case .sameCity(let city):
            "\(city)同城热搜"
        }
    }
}
