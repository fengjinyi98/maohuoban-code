import SwiftUI

// AIAssistantTimelineContentHeightKey AI 消息列表内容高度
// 核心职责：
// - 将消息列表实际高度传回页面
// - 支持自动滚动规则避免短内容贴底
struct AIAssistantTimelineContentHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
