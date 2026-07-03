import SwiftUI

// HomeRouteDestinationScreen 首页路由目标页
// 核心职责：
// - 将首页动作路由映射到对应业务页面
// - 为未接管的业务模块保留系统导航占位目标
struct HomeRouteDestinationScreen: View {
    let route: HomeRoute
    let currentUserID: String?
    var onRouteRequested: (HomeRoute) -> Void = { _ in }
    let onHomeMutationCompleted: (String?) -> Void

    var body: some View {
        switch route {
        case .petAssistant(let context):
            AIAssistantScreen(context: context)
        case .createPet:
            PetProfileAddScreen(
                currentUserID: currentUserID,
                onCreated: { petID in
                    onHomeMutationCompleted(petID)
                }
            )
        case .publishEvent(let context):
            PublishEventComposerScreen(
                context: context,
                onPrepared: {
                    onHomeMutationCompleted(nil)
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
        case .recordHealth(let context):
            PetEventRecordScreen(
                petID: context.petID,
                petSex: context.petSex,
                lifeStatus: context.lifeStatus,
                currentUserID: currentUserID,
                mode: .health,
                onRecorded: {
                    onHomeMutationCompleted(nil)
                }
            )
        case .recordAbnormal(let context):
            PetAbnormalRecordScreen(
                context: context,
                currentUserID: currentUserID,
                onRecorded: {
                    onHomeMutationCompleted(nil)
                }
            )
        case .recordWalk(let context):
            PetWalkTrackingScreen(
                context: context,
                onFinished: {
                    onHomeMutationCompleted(nil)
                }
            )
        case .petWeightDetail(let context):
            PetWeightDetailScreen(context: context)
        case .petPreventiveCare(let context):
            PetPreventiveCareScreen(context: context)
        case .petRecordHistory(let context):
            PetRecordHistoryScreen(context: context)
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
        case .petRecordDetail(let route):
            PetRecordDetailDestinationScreen(
                route: route,
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
        case .petAlbum(let context):
            PetAlbumRootScreen(
                context: context,
                currentUserID: currentUserID
            )
        case .petPantry(let petID, let petName):
            PetPantryScreen(
                petID: petID,
                petName: petName,
                currentUserID: currentUserID,
                onNavigate: { route -> HomeRoute in
                    switch route {
                    case .addItem:
                        return HomeRoute.addPantryItem(petID: petID)
                    case .categoryDetail(let category):
                        return HomeRoute.pantryCategoryDetail(petID: petID, petName: petName, category: category)
                    }
                }
            )
        case .pantryCategoryDetail(let petID, let petName, let category):
            PetPantryCategoryScreen(
                petID: petID,
                petName: petName,
                category: category,
                currentUserID: currentUserID,
                onNavigate: { route -> HomeRoute in
                    switch route {
                    case .addItem:
                        return HomeRoute.addPantryItem(petID: petID)
                    case .categoryDetail:
                        // 该页面内不产生新的分类跳转，保持当前分类上下文。
                        return HomeRoute.pantryCategoryDetail(petID: petID, petName: petName, category: category)
                    }
                }
            )
        case .addPantryItem:
            AddPantryItemScreen(
                currentUserID: currentUserID,
                onCreated: {
                    onHomeMutationCompleted(nil)
                }
            )
        }
    }
}
