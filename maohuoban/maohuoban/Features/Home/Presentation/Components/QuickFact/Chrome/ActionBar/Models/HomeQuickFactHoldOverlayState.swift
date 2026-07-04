import SwiftUI
import MaohuobanDesignSystem

// HomeQuickFactHoldOverlayState 快捷事实长按浮层状态
// 核心职责：
// - 描述屏幕中心确认浮层当前展示阶段
// - 提供浮层所需的动作文案、图标和强调色
struct HomeQuickFactHoldOverlayState: Equatable {
    let action: HomeQuickFactAction
    let phase: Phase
    let startedAt: Date
    let endedAt: Date?

    enum Phase: Equatable {
        case holding
        case cancelled
        case completed
    }

    init(
        action: HomeQuickFactAction,
        phase: Phase,
        startedAt: Date,
        endedAt: Date? = nil
    ) {
        self.action = action
        self.phase = phase
        self.startedAt = startedAt
        self.endedAt = endedAt
    }

    var title: LocalizedStringResource {
        switch phase {
        case .holding:
            "按住确认"
        case .cancelled:
            "继续按住"
        case .completed:
            "记录完成"
        }
    }

    var subtitle: LocalizedStringResource {
        switch phase {
        case .holding:
            action.title
        case .cancelled:
            "松手已取消"
        case .completed:
            action.title
        }
    }

    var accentColor: Color {
        switch action {
        case .poopNormal:
            MHBTheme.ColorToken.success.color
        case .energyNormal:
            MHBTheme.ColorToken.primary.color
        case .appetiteNormal:
            MHBTheme.ColorToken.warning.color
        case .fed:
            MHBTheme.ColorToken.primary.color
        case .abnormal:
            MHBTheme.ColorToken.danger.color
        }
    }
}
