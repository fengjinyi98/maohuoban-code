import Foundation

// HomeActionRoutingContext 首页动作路由上下文
// 核心职责：
// - 从首页快照提取当前宠物和商家主体 ID
// - 让动作映射不直接依赖完整首页快照
struct HomeActionRoutingContext: Equatable {
    let selectedPetID: String?
    let merchantID: String?
    let city: String?

    init(selectedPetID: String? = nil, merchantID: String? = nil, city: String? = nil) {
        self.selectedPetID = selectedPetID
        self.merchantID = merchantID
        self.city = city
    }

    init(snapshot: HomeDashboardSnapshot) {
        self.selectedPetID = snapshot.selectedPet?.id
        self.merchantID = snapshot.merchantDashboard?.merchantID
        self.city = snapshot.identity.city
    }
}

// HomeActionRouteResolver 首页动作路由解析器
// 核心职责：
// - 将后端下发的首页动作语义映射为本地 HomeRoute
// - 保持首页 section 只负责渲染和触发导航
enum HomeActionRouteResolver {
    static func route(
        for action: HomeDashboardSnapshot.Action,
        context: HomeActionRoutingContext
    ) -> HomeRoute? {
        switch action.kind {
        case .createPet:
            return .createPet
        case .dailyRecord:
            return .recordDaily(petID: context.selectedPetID)
        case .healthRecord:
            return .recordHealth(petID: context.selectedPetID)
        case .bookHospital:
            return .bookHospital(petID: context.selectedPetID, city: context.city)
        case .importTradePet:
            return .importTradePet
        case .addMerchantPet:
            guard let merchantID = context.merchantID, !merchantID.isEmpty else {
                return nil
            }
            return .addMerchantPet(merchantID: merchantID)
        case .publishAvailableStatus:
            guard let merchantID = context.merchantID, !merchantID.isEmpty else {
                return nil
            }
            return .publishAvailableStatus(merchantID: merchantID)
        }
    }
}

// HomeReminderRouteResolver 首页提醒路由解析器
// 核心职责：
// - 将首页提醒摘要映射为本地导航目标
// - 复用事件详情和商家待办入口，避免首页承载深层提醒规则
enum HomeReminderRouteResolver {
    static func route(
        for reminder: HomeDashboardSnapshot.Reminder,
        context: HomeActionRoutingContext
    ) -> HomeRoute? {
        switch reminder.kind {
        case .merchantTask:
            guard let merchantID = context.merchantID, !merchantID.isEmpty else {
                return nil
            }
            return .merchantTask(merchantID: merchantID, reminderID: reminder.id)
        case .vaccine, .deworming, .followUp, .completeHealthRecord:
            return .timelineEvent(eventID: reminder.id)
        }
    }
}
