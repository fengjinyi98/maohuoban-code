import CoreGraphics
import MaohuobanDesignSystem

// HomeQuickActionsFloatingSurfaceState 首页快捷菜单 surface 插值状态
// 核心职责：
// - 统一描述按钮到面板的单宿主尺寸与圆角插值
// - 为 SwiftUI 动画层提供稳定的纯函数输入
struct HomeQuickActionsFloatingSurfaceState {
    nonisolated let progress: CGFloat
    nonisolated let width: CGFloat
    nonisolated let height: CGFloat
    nonisolated let cornerRadius: CGFloat
    nonisolated let plusOpacity: CGFloat
    nonisolated let plusRotationDegrees: CGFloat

    nonisolated init(
        progress: CGFloat,
        expandedWidth: CGFloat,
        expandedHeight: CGFloat
    ) {
        let clampedProgress = min(max(progress, 0), 1)
        let collapsedSide = HomeQuickActionsFloatingMetrics.collapsedSide
        let collapsedRadius = collapsedSide / 2
        let expandedRadius = MHBTheme.Radius.extraLarge

        self.progress = clampedProgress
        self.width = Self.interpolate(
            from: collapsedSide,
            to: expandedWidth,
            progress: clampedProgress
        )
        self.height = Self.interpolate(
            from: collapsedSide,
            to: expandedHeight,
            progress: clampedProgress
        )
        self.cornerRadius = Self.interpolate(
            from: collapsedRadius,
            to: expandedRadius,
            progress: clampedProgress
        )
        self.plusOpacity = 1 - clampedProgress
        self.plusRotationDegrees = 45 * clampedProgress
    }

    private nonisolated static func interpolate(
        from start: CGFloat,
        to end: CGFloat,
        progress: CGFloat
    ) -> CGFloat {
        start + (end - start) * progress
    }
}
