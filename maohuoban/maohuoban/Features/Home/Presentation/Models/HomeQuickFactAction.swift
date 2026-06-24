import Foundation

// HomeQuickFactAction 首页快捷事实动作
// 核心职责：
// - 定义底部快捷事实条的低摩擦动作集合
// - 将正常事实转换为宠物事件草稿，异常入口交给健康记录流程
enum HomeQuickFactAction: String, CaseIterable, Equatable, Identifiable, Sendable {
    case fed
    case poopNormal
    case energyNormal
    case appetiteNormal
    case abnormal

    var id: String { rawValue }

    static var defaultActions: [HomeQuickFactAction] {
        [.fed, .poopNormal, .energyNormal, .appetiteNormal, .abnormal]
    }

    var title: LocalizedStringResource {
        switch self {
        case .fed: "已喂"
        case .poopNormal: "便便正常"
        case .energyNormal: "精神不错"
        case .appetiteNormal: "食欲正常"
        case .abnormal: "异常"
        }
    }

    var systemImage: String {
        switch self {
        case .fed: "fork.knife"
        case .poopNormal: "checkmark.seal.fill"
        case .energyNormal: "face.smiling"
        case .appetiteNormal: "takeoutbag.and.cup.and.straw.fill"
        case .abnormal: "cross.case.fill"
        }
    }

    var accessibilityIdentifier: String {
        "home.quickFact.\(rawValue)"
    }

    func eventDraft(occurredAt: Date) -> PetEventDraft? {
        guard let summary = directEventSummary else { return nil }

        return PetEventDraft(
            kind: .daily,
            subkind: "quick_fact",
            title: eventTitle,
            summary: summary,
            visibility: .private,
            occurredAt: PetWriteFormatters.occurredAtString(from: occurredAt)
        )
    }

    private var eventTitle: String {
        switch self {
        case .fed: "已喂"
        case .poopNormal: "便便正常"
        case .energyNormal: "精神不错"
        case .appetiteNormal: "食欲正常"
        case .abnormal: "异常"
        }
    }

    private var directEventSummary: String? {
        switch self {
        case .fed: "完成喂食"
        case .poopNormal: "粪便状态：健康成型"
        case .energyNormal: "精神与活力：正常平稳"
        case .appetiteNormal: "食欲正常"
        case .abnormal: nil
        }
    }
}

// HomeQuickFactActionRouteResolver 首页快捷事实路由解析器
// 核心职责：
// - 将需要补充上下文的快捷事实动作映射为首页导航目标
// - 保持底部快捷条不直接构造复杂业务页面
enum HomeQuickFactActionRouteResolver {
    static func route(
        for action: HomeQuickFactAction,
        context: HomeActionRoutingContext
    ) -> HomeRoute? {
        switch action {
        case .abnormal:
            let healthAction = HomeDashboardSnapshot.Action(
                kind: .healthRecord,
                title: "健康记录",
                subtitle: nil
            )
            return HomeActionRouteResolver.route(
                for: healthAction,
                context: context
            )
        case .fed, .poopNormal, .energyNormal, .appetiteNormal:
            return nil
        }
    }
}
