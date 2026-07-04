import SwiftUI

// HomeRouteDestinationScreen 首页路由目标页
// 核心职责：
// - 将首页动作路由映射到对应业务页面
// - 为未接管的业务模块保留系统导航占位目标
struct HomeRouteDestinationScreen: View {
    let route: HomeRoute
    let currentUserID: String?
    var onRouteRequested: (HomeRoute) -> Void = { _ in }
    var deletedRecordID: String? = nil
    var onRecordDeleted: (String) -> Void = { _ in }
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
        case .medicalRecords(let context):
            PetMedicalRecordScreen(
                context: context,
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
        case .petWeightRecordDetail(let recordID, let context):
            PetWeightRecordRouteScreen(
                recordID: recordID,
                context: context,
                currentUserID: currentUserID,
                onDeleted: { deletedRecordID in
                    onRecordDeleted(deletedRecordID)
                    onHomeMutationCompleted(nil)
                }
            )
        case .petPreventiveCare(let context):
            PetPreventiveCareScreen(
                context: context,
                currentUserID: currentUserID,
                onRecordDeleted: { deletedRecordID in
                    onRecordDeleted(deletedRecordID)
                    onHomeMutationCompleted(nil)
                },
                onMutationCompleted: {
                    onHomeMutationCompleted(nil)
                }
            )
        case .petRecordHistory(let context):
            PetRecordHistoryScreen(
                context: context,
                currentUserID: currentUserID,
                deletedRecordID: deletedRecordID,
                onOpenRecordDetail: { detailRoute in
                    onRouteRequested(.petRecordDetail(detailRoute))
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
        case .petRecordDetail(let route):
            PetRecordDetailDestinationScreen(
                route: route,
                currentUserID: currentUserID,
                onRecordDeleted: { recordID in
                    onRecordDeleted(recordID)
                    onHomeMutationCompleted(nil)
                }
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
        case .allReminders(let reminders, let context):
            HomeAllRemindersScreen(
                reminders: reminders,
                routingContext: context,
                onOpenRoute: onRouteRequested
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
            PetAlbumRootScreen<HomeRoute>(
                context: context,
                currentUserID: currentUserID,
                createRoute: .petAlbumDestination(context: context, destination: .create),
                detailRoute: { album in
                    .petAlbumDestination(context: context, destination: .detail(album))
                },
                editRoute: { editContext in
                    .petAlbumDestination(context: context, destination: .edit(editContext))
                },
                onOpenRoute: onRouteRequested
            )
        case .petAlbumDestination(let context, let destination):
            PetAlbumRouteDestinationScreen(
                context: context,
                currentUserID: currentUserID,
                destination: destination
            )
        case .petDietTrendDetail(let summary, let petName):
            HomeDietTrendDetailScreen(
                petName: petName,
                summary: summary
            )
        case .petPantry(let context):
            PetPantryScreen(
                context: context,
                currentUserID: currentUserID,
                onNavigate: { route -> HomeRoute in
                    switch route {
                    case .addItem:
                        return HomeRoute.addPantryItem
                    case .editItem(let item):
                        return HomeRoute.editPantryItem(item)
                    case .itemDetail(let itemID):
                        return HomeRoute.pantryItemDetail(context: context, itemID: itemID)
                    case .categoryDetail(let category):
                        return HomeRoute.pantryCategoryDetail(context: context, category: category)
                    }
                },
                onOpenRoute: onRouteRequested
            )
        case .pantryCategoryDetail(let context, let category):
            PetPantryCategoryScreen(
                context: context,
                category: category,
                currentUserID: currentUserID,
                onNavigate: { route -> HomeRoute in
                    switch route {
                    case .addItem:
                        return HomeRoute.addPantryItem
                    case .editItem(let item):
                        return HomeRoute.editPantryItem(item)
                    case .itemDetail(let itemID):
                        return HomeRoute.pantryItemDetail(context: context, itemID: itemID)
                    case .categoryDetail:
                        // 该页面内不产生新的分类跳转，保持当前分类上下文。
                        return HomeRoute.pantryCategoryDetail(context: context, category: category)
                    }
                },
                onOpenRoute: onRouteRequested
            )
        case .pantryItemDetail(let context, let itemID):
            PantryItemDetailScreen(
                itemID: itemID,
                context: context,
                currentUserID: currentUserID,
                onNavigate: { route -> HomeRoute in
                    switch route {
                    case .addItem:
                        return HomeRoute.addPantryItem
                    case .editItem(let item):
                        return HomeRoute.editPantryItem(item)
                    case .itemDetail(let itemID):
                        return HomeRoute.pantryItemDetail(context: context, itemID: itemID)
                    case .categoryDetail(let category):
                        return HomeRoute.pantryCategoryDetail(context: context, category: category)
                    }
                },
                onOpenRoute: onRouteRequested
            )
        case .addPantryItem:
            AddPantryItemScreen(
                mode: .create,
                currentUserID: currentUserID,
                onSaved: {
                    onHomeMutationCompleted(nil)
                }
            )
        case .editPantryItem(let item):
            AddPantryItemScreen(
                mode: .edit(item),
                currentUserID: currentUserID,
                onSaved: {
                    onHomeMutationCompleted(nil)
                }
            )
        }
    }
}
