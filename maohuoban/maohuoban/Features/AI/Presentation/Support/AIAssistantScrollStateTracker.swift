import Foundation

// AIAssistantAutoScrollMode 自动滚动模式
nonisolated enum AIAssistantAutoScrollMode: Equatable {
    case followBottom
    case manual
}

// AIAssistantScrollStateTracker 滚动状态追踪器
// 核心职责：
// - 纯函数管理自动滚动模式切换
// - 用户拖动时暂停自动跟随
// - 拖动结束在底部时恢复自动跟随
nonisolated struct AIAssistantScrollStateTracker {

    static let userScrollCooldown: TimeInterval = 0.25

    /// 用户拖动开始时切换到 manual
    static func modeAfterUserDragBegan(
        currentMode: AIAssistantAutoScrollMode
    ) -> AIAssistantAutoScrollMode {
        .manual
    }

    /// 用户拖动结束后，在底部恢复 followBottom，否则保持 manual
    static func modeAfterUserDragEnded(
        currentMode: AIAssistantAutoScrollMode,
        isScrolledToBottom: Bool
    ) -> AIAssistantAutoScrollMode {
        isScrolledToBottom ? .followBottom : .manual
    }

    /// 判断当前是否应自动滚动到底部
    static func shouldAutoScroll(
        currentMode: AIAssistantAutoScrollMode,
        isUserDragging: Bool,
        cooldownUntil: Date?
    ) -> Bool {
        guard currentMode == .followBottom else { return false }
        if isUserDragging { return false }
        if let cooldownUntil, Date() < cooldownUntil { return false }
        return true
    }

    /// 是否显示"滚动到最新"按钮
    static func shouldShowScrollToLatestButton(
        messageCount: Int,
        isScrolledToBottom: Bool,
        hasUserScrolled: Bool,
        contentHeight: CGFloat,
        viewportHeight: CGFloat
    ) -> Bool {
        messageCount > 0
            && hasUserScrolled
            && canScroll(contentHeight: contentHeight, viewportHeight: viewportHeight, threshold: 28)
            && !isScrolledToBottom
    }

    /// 内容是否具备真实滚动空间
    /// 核心职责：
    /// - 统一可滚动判定阈值
    /// - 避免悬浮控件显隐造成边界抖动
    static func canScroll(
        contentHeight: CGFloat,
        viewportHeight: CGFloat,
        threshold: CGFloat
    ) -> Bool {
        contentHeight - viewportHeight > threshold
    }

    /// 是否应标记用户已经主动离开底部
    /// 核心职责：
    /// - 只把用户滚动意图转换成按钮显隐触发
    /// - 避免内容自动增长误触发回到底部按钮
    static func shouldMarkUserScrolled(
        isScrolledToBottom: Bool,
        hasUserScrollIntent: Bool
    ) -> Bool {
        hasUserScrollIntent && !isScrolledToBottom
    }

    /// 内容增长后是否继续跟随底部
    /// 核心职责：
    /// - 用户未主动离开时保持最新消息可见
    /// - 用户主动浏览历史时停止自动跟随
    static func shouldFollowBottomAfterContentGrowth(
        previousIsScrolledToBottom: Bool,
        hasUserScrolled: Bool,
        hasUserScrollIntent: Bool,
        previousContentHeight: CGFloat,
        nextContentHeight: CGFloat,
        viewportHeight: CGFloat
    ) -> Bool {
        guard nextContentHeight > previousContentHeight else { return false }
        guard nextContentHeight > viewportHeight else { return false }
        guard hasUserScrollIntent == false else { return false }
        return previousIsScrolledToBottom && !hasUserScrolled
    }

    /// 是否需要将内容滚动到底部
    /// 核心职责：
    /// - 内容未超过视口时保持顶部自然布局
    /// - 内容超过视口时允许跟随最新消息
    static func shouldAutoScrollToBottom(
        contentHeight: CGFloat,
        viewportHeight: CGFloat
    ) -> Bool {
        contentHeight > viewportHeight
    }

    /// 是否已经滚动到消息列表底部
    /// 核心职责：
    /// - 基于系统滚动几何计算底部距离
    /// - 为回到最新按钮提供稳定显隐依据
    static func isScrolledToBottom(
        contentOffsetY: CGFloat,
        visibleMaxY: CGFloat,
        contentHeight: CGFloat,
        viewportHeight: CGFloat,
        threshold: CGFloat
    ) -> Bool {
        guard canScroll(
            contentHeight: contentHeight,
            viewportHeight: viewportHeight,
            threshold: threshold
        ) else {
            return true
        }
        return contentHeight - visibleMaxY <= threshold
    }
}
