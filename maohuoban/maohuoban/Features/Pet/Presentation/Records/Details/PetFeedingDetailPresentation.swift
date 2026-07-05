import Foundation
import MaohuobanDesignSystem

// PetFeedingDetailPresentation 喂食详情展示模型
// 核心职责：
// - 将后端事件详情映射为喂食详情展示字段
// - 约束喂食详情字段只展示当前产品边界内的信息
struct PetFeedingDetailPresentation {
    struct Pet: Equatable {
        let id: String
        let name: String
        let avatarSource: MHBAvatarSource
        let sex: MHBAvatarSex

        var avatarPet: MHBAvatarPet {
            MHBAvatarPet(
                id: id,
                name: name,
                source: avatarSource,
                species: .other,
                sex: sex
            )
        }
    }

    struct Food: Equatable {
        let name: String
        let subtitle: String
        let imageURLString: String?
        let systemImage: String
    }

    let recordID: String
    let title: String
    let pet: Pet
    let timeText: String
    let amountText: String
    let food: Food
    let note: String
    let attachmentAssetIDs: [String]

    init(event: PetEventDetail, recordContext: PetRecordEntryContext) {
        let payload = event.eventPayload
        let eventTitle = event.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let noteText = payload?.note?.trimmingCharacters(in: .whitespacesAndNewlines)

        self.recordID = event.id
        self.title = eventTitle.isEmpty ? "已喂食记录" : eventTitle
        self.pet = Self.petIdentity(event: event, context: recordContext)
        self.timeText = MHBUTCDateDisplayFormatter.localShortText(fromUTCString: event.occurredAt)
            ?? event.occurredAt
        self.amountText = payload?.amountText?.isEmpty == false ? payload?.amountText ?? "未记录" : "未记录"
        self.food = Self.food(payload: payload)
        self.note = noteText?.isEmpty == false ? noteText ?? "未填写备注" : "未填写备注"
        self.attachmentAssetIDs = payload?.attachmentAssetIDs ?? []
    }

    private static func petIdentity(
        event: PetEventDetail,
        context: PetRecordEntryContext
    ) -> Pet {
        Pet(
            id: context.resolvedPetID ?? event.petID ?? "",
            name: context.resolvedPetName ?? "",
            avatarSource: petAvatarSource(context: context),
            sex: context.resolvedPetSex.avatarSex
        )
    }

    private static func petAvatarSource(context: PetRecordEntryContext) -> MHBAvatarSource {
        guard let avatarURLString = context.petAvatarURL ?? context.selectedSwitchPet?.avatarURL,
              let avatarURL = MHBBackendEndpoint.resolve(avatarURLString) else {
            return .empty
        }
        return .remote(avatarURL)
    }

    private static func food(payload: PetEventDetailPayload?) -> Food {
        let roleTitle = foodRoleTitle(payload?.foodRole)
        let snapshot = payload?.foodSnapshot
        let name = snapshot?.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = name?.isEmpty == false ? name ?? roleTitle : roleTitle
        let subtitleParts = [
            snapshot?.brand,
            snapshot?.spec
        ]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let subtitle = subtitleParts.isEmpty ? roleTitle : subtitleParts.joined(separator: " · ")

        return Food(
            name: title,
            subtitle: subtitle,
            imageURLString: snapshot?.coverURL,
            systemImage: foodRoleSystemImage(payload?.foodRole)
        )
    }

    private static func foodRoleTitle(_ rawValue: String?) -> String {
        switch rawValue {
        case "main_food":
            "主粮"
        case "wet_food":
            "罐头/湿粮"
        case "treats":
            "零食"
        case "nutrition":
            "营养品"
        case "other":
            "其他食品"
        default:
            "喂食食品"
        }
    }

    private static func foodRoleSystemImage(_ rawValue: String?) -> String {
        switch rawValue {
        case "wet_food":
            "fork.knife.circle.fill"
        case "nutrition":
            "pills.fill"
        case "treats":
            "birthday.cake.fill"
        default:
            "takeoutbag.and.cup.and.straw.fill"
        }
    }
}
