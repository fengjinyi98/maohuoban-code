import Foundation

// HomeQuickActionPresentation 首页快捷动作展示语义
// 核心职责：
// - 统一维护首页快捷动作的图标与副标题文案
// - 为浮动菜单和后续入口复用同一套展示规则
enum HomeQuickActionPresentation {
    nonisolated static func iconName(for kind: HomeDashboardSnapshot.Action.Kind) -> String {
        switch kind {
        case .createPet: "plus.circle.fill"
        case .dailyRecord: "square.and.pencil"
        case .walk: "figure.walk"
        case .healthRecord: "cross.case.fill"
        case .preventiveCare: "syringe"
        case .addReminder: "bell.badge.fill"
        case .bookHospital: "stethoscope"
        case .importTradePet: "tray.and.arrow.down.fill"
        case .addMerchantPet: "pawprint.circle.fill"
        case .publishAvailableStatus: "tag.fill"
        }
    }

    nonisolated static func subtitle(for action: HomeDashboardSnapshot.Action) -> String {
        if let subtitle = action.subtitle?.trimmingCharacters(in: .whitespacesAndNewlines),
           !subtitle.isEmpty {
            return subtitle
        }

        return fallbackSubtitle(for: action.kind)
    }

    private nonisolated static func fallbackSubtitle(
        for kind: HomeDashboardSnapshot.Action.Kind
    ) -> String {
        switch kind {
        case .createPet:
            "从犬猫档案开始记录身份与关系"
        case .dailyRecord:
            "补一条吃喝拉撒睡的今天日常"
        case .walk:
            "开始一段新的遛弯轨迹与事件"
        case .healthRecord:
            "记录症状、用药和门诊检查"
        case .preventiveCare:
            "管理疫苗、驱虫和复查节点"
        case .addReminder:
            "为喂养、护理和复诊创建提醒"
        case .bookHospital:
            "查看附近医院并发起到诊安排"
        case .importTradePet:
            "导入交易宠物并补齐基础档案"
        case .addMerchantPet:
            "新增在售宠物并补充卖点资料"
        case .publishAvailableStatus:
            "同步在售宠物与档期状态"
        }
    }
}
