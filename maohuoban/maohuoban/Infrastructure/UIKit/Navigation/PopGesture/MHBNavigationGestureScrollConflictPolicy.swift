import CoreGraphics

// MHBNavigationGestureScrollConflictPolicy 导航手势滚动冲突策略
// 核心职责：
// - 判断系统侧滑返回能否与横向滚动容器协同
// - 仅在横向内容位于最左侧时允许返回手势接管
enum MHBNavigationGestureScrollConflictPolicy {
    nonisolated static func shouldAllowPopGesture(
        contentSize: CGSize,
        bounds: CGRect,
        contentOffset: CGPoint,
        adjustedContentInsetLeft: CGFloat
    ) -> Bool {
        let horizontalOverflow = contentSize.width - bounds.width
        guard horizontalOverflow > 0.5 else {
            return true
        }

        let leadingEdgeOffset = -adjustedContentInsetLeft
        return contentOffset.x <= leadingEdgeOffset + 0.5
    }
}
