import CoreGraphics
import MaohuobanDesignSystem

// HomeQuickActionsFloatingMetrics 首页快捷动作浮动菜单尺寸配置
// 核心职责：
// - 统一收敛按钮与展开面板的尺寸参数
// - 为单容器膨胀动画提供稳定布局基准
enum HomeQuickActionsFloatingMetrics {
    nonisolated static let collapsedSide: CGFloat = 58
    nonisolated static let expandedWidthCap: CGFloat = 316
    nonisolated static let expandedWidthFloor: CGFloat = 252
    nonisolated static let expandedMinHeight: CGFloat = 220
    nonisolated static let expandedMaxHeight: CGFloat = 440
    nonisolated static let rowHeight: CGFloat = 72
    nonisolated static let rowSpacing: CGFloat = MHBTheme.Spacing.s1
    nonisolated static let headerHeight: CGFloat = 40
    nonisolated static let horizontalMargin: CGFloat = 16
    nonisolated static let verticalMargin: CGFloat = 24

    nonisolated static func expandedWidth(for availableWidth: CGFloat) -> CGFloat {
        min(max(expandedWidthFloor, availableWidth), expandedWidthCap)
    }

    nonisolated static func expandedHeight(actionCount: Int, availableHeight: CGFloat) -> CGFloat {
        let rowsHeight = CGFloat(actionCount) * rowHeight
        let rowsSpacing = CGFloat(max(actionCount - 1, 0)) * rowSpacing
        let contentHeight = headerHeight + rowsHeight + rowsSpacing + 32
        let clampedAvailableHeight = max(expandedMinHeight, availableHeight)
        return min(
            max(expandedMinHeight, contentHeight),
            min(expandedMaxHeight, clampedAvailableHeight)
        )
    }
}
