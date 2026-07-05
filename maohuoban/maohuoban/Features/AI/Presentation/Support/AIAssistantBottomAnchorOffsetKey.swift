import SwiftUI

// AIAssistantBottomAnchorOffsetKey AI 消息底部锚点位置
// 核心职责：
// - 将消息列表底部在滚动坐标系中的位置传回页面
// - 支持回到最新按钮的显隐判断
struct AIAssistantBottomAnchorOffsetKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
