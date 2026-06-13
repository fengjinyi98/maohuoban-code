import SwiftUI

// HomeRouteDestinationScreen 首页路由目标页
// 核心职责：
// - 将首页动作路由映射到对应业务页面
// - 为未接管的业务模块保留系统导航占位目标
struct HomeRouteDestinationScreen: View {
    let route: HomeRoute
    let currentUserID: String?
    let onHomeMutationCompleted: () -> Void

    var body: some View {
        switch route {
        case .createPet:
            PetCreateScreen(
                currentUserID: currentUserID,
                onCreated: onHomeMutationCompleted
            )
        case .recordDaily(let petID):
            PetEventRecordScreen(
                petID: petID,
                currentUserID: currentUserID,
                mode: .daily,
                onRecorded: onHomeMutationCompleted
            )
        case .recordHealth(let petID):
            PetEventRecordScreen(
                petID: petID,
                currentUserID: currentUserID,
                mode: .health,
                onRecorded: onHomeMutationCompleted
            )
        case .merchantPets(let merchantID, let status):
            if let status = MerchantPetStatus(rawValue: status) {
                MerchantPetsScreen(
                    merchantID: merchantID,
                    status: status,
                    currentUserID: currentUserID
                )
            } else {
                MHBTabPlaceholderRootScreen(
                    systemImage: route.systemImage,
                    title: route.title,
                    subtitle: "商家宠物状态参数无效",
                    accessibilityIdentifier: "home.routeDestination"
                )
            }
        case .addMerchantPet(let merchantID):
            MerchantPetCreateScreen(
                merchantID: merchantID,
                currentUserID: currentUserID,
                onCreated: onHomeMutationCompleted
            )
        case .merchantLitter(let merchantID, let litterID):
            MerchantLitterDetailScreen(
                merchantID: merchantID,
                litterID: litterID,
                currentUserID: currentUserID
            )
        case .timelineEvent(let eventID):
            PetEventDetailScreen(
                eventID: eventID,
                currentUserID: currentUserID
            )
        case .publishAvailableStatus(let merchantID):
            MerchantAvailableStatusScreen(
                merchantID: merchantID,
                currentUserID: currentUserID,
                onPublished: onHomeMutationCompleted
            )
        case .bookHospital,
             .importTradePet,
             .merchantTask:
            MHBTabPlaceholderRootScreen(
                systemImage: route.systemImage,
                title: route.title,
                subtitle: route.subtitle,
                accessibilityIdentifier: "home.routeDestination"
            )
        }
    }
}
