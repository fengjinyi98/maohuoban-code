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
        case .recordDaily(let context):
            PetEventRecordScreen(
                petID: context.recordContext.petID,
                petSex: context.recordContext.petSex,
                currentUserID: currentUserID,
                mode: .daily,
                onRecordAndPublish: {
                    onRouteRequested(.publishEvent(context.publishContext))
                },
                onRecorded: {
                    onHomeMutationCompleted(nil)
                }
            )
        case .recordHealth(let context):
            PetEventRecordScreen(
                petID: context.petID,
                petSex: context.petSex,
                currentUserID: currentUserID,
                mode: .health,
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
        case .petAlbumList:
            PetAlbumListScreen(
                createRoute: HomeRoute.createPetAlbum,
                detailRoute: { album in
                    HomeRoute.petAlbumDetail(albumID: album.id)
                },
                editRoute: { context in
                    HomeRoute.editPetAlbum(context)
                },
                onOpenRoute: onRouteRequested
            )
        case .createPetAlbum:
            PetAlbumCreateScreen()
        case .editPetAlbum(let context):
            PetAlbumCreateScreen(mode: .edit(context))
        case .petAlbumDetail(let albumID):
            PetAlbumDetailScreen(albumID: albumID)
        case .petPantry(let petID, let petName):
            PetPantryScreen(
                petID: petID,
                petName: petName,
                onNavigate: { route -> HomeRoute in
                    switch route {
                    case .addItem:
                        return HomeRoute.addPantryItem(petID: petID)
                    }
                }
            )
        case .addPantryItem:
            AddPantryItemScreen()
        }
    }
}
