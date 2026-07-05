import SwiftUI

// PetRecordDetailAutoRouteScreen 记录详情自动分发页
// 核心职责：
// - 在只有 event ID 的入口加载事件详情
// - 根据事件真实类型分发到对应业务详情页
struct PetRecordDetailAutoRouteScreen: View {
    let recordID: String
    let context: PetRecordEntryContext
    var currentUserID: String? = nil
    var onRecordDeleted: (String) -> Void = { _ in }

    @State private var store = PetEventDetailStore()

    var body: some View {
        Group {
            switch store.phase {
            case .idle, .loading:
                PetRecordDetailAutoRouteLoadingView()
            case .loaded(let event):
                PetRecordDetailDestinationScreen(
                    route: PetRecordDetailAutoRouteResolver.route(
                        for: event,
                        context: contextFor(event)
                    ),
                    currentUserID: currentUserID,
                    onRecordDeleted: onRecordDeleted
                )
            case .deleted(let recordID):
                PetRecordDetailPlaceholderScreen(
                    systemImage: "trash",
                    title: "记录已删除",
                    subtitle: "这条记录已经删除。",
                    accessibilityIdentifier: "pet.recordDetail.auto.deleted.\(recordID)"
                )
            case .failed:
                PetRecordDetailPlaceholderScreen(
                    systemImage: "exclamationmark.triangle",
                    title: "记录无法打开",
                    subtitle: "请稍后重试或回到记录列表查看。",
                    accessibilityIdentifier: "pet.recordDetail.auto.failed"
                )
            }
        }
        .task(id: recordID) {
            await store.load(eventID: recordID, currentUserID: currentUserID)
        }
    }

    private func contextFor(_ event: PetEventDetail) -> PetRecordEntryContext {
        guard let petID = event.petID, context.resolvedPetID != petID else {
            return context
        }

        return PetRecordEntryContext(
            petID: petID,
            petName: context.petName,
            petAvatarURL: context.petAvatarURL,
            petSex: context.petSex,
            lifeStatus: context.lifeStatus,
            availablePets: context.availablePets
        )
    }
}
