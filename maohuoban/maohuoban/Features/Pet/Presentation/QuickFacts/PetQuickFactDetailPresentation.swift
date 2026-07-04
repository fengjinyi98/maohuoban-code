import SwiftUI
import MaohuobanDesignSystem

// PetQuickFactDetailPresentation 快速事实展示模型
// 核心职责：
// - 将后端事件详情和入口宠物上下文转换为小票展示数据
// - 让快速事实详情页只消费单向传入的事件状态
struct PetQuickFactDetailPresentation {
    struct PetIdentity: Equatable {
        let id: String
        let name: String
        let avatarSource: MHBAvatarSource
    }

    enum RowValue: Equatable {
        case text(String)
        case pet(PetIdentity)
    }

    struct Row: Identifiable {
        let id: String
        let title: String
        let value: RowValue

        init(id: String, title: String, text: String) {
            self.id = id
            self.title = title
            self.value = .text(text)
        }

        init(id: String, title: String, pet: PetIdentity) {
            self.id = id
            self.title = title
            self.value = .pet(pet)
        }
    }

    let title: String
    let timeText: String
    let systemImage: String
    let tint: Color
    let rows: [Row]

    init(
        event: PetEventDetail,
        kind: PetQuickFactDetailKind,
        recordContext: PetRecordEntryContext
    ) {
        let eventTitle = event.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let summaryText = event.summary?.trimmingCharacters(in: .whitespacesAndNewlines)

        self.title = eventTitle.isEmpty ? kind.title : eventTitle
        self.timeText = MHBUTCDateDisplayFormatter.localShortText(fromUTCString: event.occurredAt)
            ?? event.occurredAt
        self.systemImage = kind.systemImage
        self.tint = kind.tint
        self.rows = [
            .init(
                id: "pet",
                title: "宠物",
                pet: Self.petIdentity(event: event, context: recordContext)
            ),
            .init(id: "type", title: "记录类型", text: kind.recordTypeTitle),
            .init(
                id: "content",
                title: "内容",
                text: summaryText?.isEmpty == false ? summaryText ?? kind.contentText : kind.contentText
            )
        ]
    }

    private static func petIdentity(
        event: PetEventDetail,
        context: PetRecordEntryContext
    ) -> PetIdentity {
        PetIdentity(
            id: context.resolvedPetID ?? event.petID ?? "",
            name: context.resolvedPetName ?? "",
            avatarSource: petAvatarSource(context: context)
        )
    }

    private static func petAvatarSource(context: PetRecordEntryContext) -> MHBAvatarSource {
        guard let avatarURLString = context.petAvatarURL ?? context.selectedSwitchPet?.avatarURL,
              let avatarURL = MHBBackendEndpoint.resolve(avatarURLString) else {
            return .empty
        }
        return .remote(avatarURL)
    }
}
