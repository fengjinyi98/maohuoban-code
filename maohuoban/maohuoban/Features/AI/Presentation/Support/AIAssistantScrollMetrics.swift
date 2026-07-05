import CoreGraphics

// AIAssistantScrollMetrics AI 会话滚动几何
// 核心职责：
// - 承接系统 ScrollGeometry 的关键滚动值
// - 支持回到最新按钮的底部状态判定
struct AIAssistantScrollMetrics: Equatable {
    let contentOffsetY: CGFloat
    let visibleMaxY: CGFloat
    let contentHeight: CGFloat
    let viewportHeight: CGFloat
}
