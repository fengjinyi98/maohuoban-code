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
        isScrolledToBottom: Bool
    ) -> Bool {
        messageCount > 0 && !isScrolledToBottom
    }
}
