import Foundation

// ProfileReplyScope 我的回复范围
// 核心职责：
// - 描述我的回复页面的收到和发出两类范围
// - 为系统 tabs Picker 和搜索提示提供稳定文案
enum ProfileReplyScope: String, CaseIterable, Identifiable, Hashable {
    case received
    case sent

    var id: String { rawValue }

    var title: String {
        switch self {
        case .received: "收到的回复"
        case .sent:     "发出的回复"
        }
    }

    var emptyTitle: String {
        switch self {
        case .received: "暂无收到的回复"
        case .sent:     "暂无发出的回复"
        }
    }
}
