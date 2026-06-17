import SwiftUI

// HomeRouteDestinationScreen 首页路由目标页
// 核心职责：
// - 将首页动作路由映射到对应业务页面
// - 为未接管的业务模块保留系统导航占位目标
struct HomeRouteDestinationScreen: View {
    let route: HomeRoute
    let currentUserID: String?
    let onHomeMutationCompleted: (String?) -> Void

    var body: some View {
        switch route {
        case .createPet:
            PetProfileAddScreen(
                currentUserID: currentUserID,
                onCreated: { petID in
                    onHomeMutationCompleted(petID)
                }
            )
        case .editPetProfile(let context):
            PetProfileEditScreen(
                context: context,
                currentUserID: currentUserID,
                onPetCreated: {
                    onHomeMutationCompleted(nil)
                }
            )
        case .recordDaily(let petID):
            PetEventRecordScreen(
                petID: petID,
                currentUserID: currentUserID,
                mode: .daily,
                onRecorded: {
                    onHomeMutationCompleted(nil)
                }
            )
        case .recordHealth(let petID):
            PetEventRecordScreen(
                petID: petID,
                currentUserID: currentUserID,
                mode: .health,
                onRecorded: {
                    onHomeMutationCompleted(nil)
                }
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
                onCreated: {
                    onHomeMutationCompleted(nil)
                }
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
                onPublished: {
                    onHomeMutationCompleted(nil)
                }
            )
        case .merchantTask(let merchantID, _):
            MerchantPetsScreen(
                merchantID: merchantID,
                status: .needsRecord,
                currentUserID: currentUserID
            )
        case .importTradePet:
            PetTradeImportScreen(
                currentUserID: currentUserID,
                onImported: {
                    onHomeMutationCompleted(nil)
                }
            )
        case .bookHospital(let petID, let city):
            HospitalBookingScreen(
                currentUserID: currentUserID,
                petID: petID,
                city: city,
                onBooked: {
                    onHomeMutationCompleted(nil)
                }
            )
        }
    }
}
