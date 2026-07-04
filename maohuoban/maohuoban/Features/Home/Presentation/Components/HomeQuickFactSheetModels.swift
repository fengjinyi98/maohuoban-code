import Foundation

// HomeQuickFactSheet 快捷事实弹层类型
// 核心职责：
// - 区分需要补充上下文的快捷动作
// - 为 sheet(item:) 提供稳定身份
enum HomeQuickFactSheet: String, Identifiable {
    case feeding

    var id: String { rawValue }
}

// HomeQuickFactFeedingFoodKind 喂食食品类型
// 核心职责：
// - 承载喂食 sheet 中的食品粗分类
// - 为后续接入食品库保留稳定语义
enum HomeQuickFactFeedingFoodKind: String, CaseIterable, Identifiable {
    case mainFood
    case wetFood
    case snack
    case supplement
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mainFood: "主粮"
        case .wetFood: "湿粮/罐头"
        case .snack: "零食"
        case .supplement: "营养品"
        case .other: "其他"
        }
    }

    var systemImage: String {
        switch self {
        case .mainFood: "takeoutbag.and.cup.and.straw.fill"
        case .wetFood: "cup.and.saucer.fill"
        case .snack: "birthday.cake.fill"
        case .supplement: "pills.fill"
        case .other: "ellipsis.circle.fill"
        }
    }
}

// HomeQuickFactFeedingAmount 喂食份量选项
// 核心职责：
// - 承载低摩擦喂食份量描述
// - 生成用户可读的喂食事件摘要
enum HomeQuickFactFeedingAmount: String, CaseIterable, Identifiable {
    case small
    case normal
    case more

    var id: String { rawValue }

    var title: String {
        switch self {
        case .small: "少量"
        case .normal: "正常"
        case .more: "多一点"
        }
    }
}

// HomeQuickFactFeedingInput 喂食快捷记录输入
// 核心职责：
// - 汇总喂食 sheet 的提交数据
// - 转换为现有宠物事件草稿
struct HomeQuickFactFeedingInput: Equatable {
    let petID: String?
    let lifeStatus: String?
    let foodKind: HomeQuickFactFeedingFoodKind
    let foodName: String?
    /// 引用的储物柜食品资产 ID（nil 表示手动输入）
    let foodItemID: String?
    /// 喂食时的食品快照 JSON 字符串（对抗后续编辑）
    let foodSnapshotJSON: String?
    let isDefaultFood: Bool
    let amount: HomeQuickFactFeedingAmount
    let occurredAt: Date
    let note: String
    let attachmentAssetIDs: [String]

    func eventDraft() -> PetEventDraft {
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let noteText = trimmedNote.isEmpty ? "" : "，备注：\(trimmedNote)"
        let foodText = foodName?.isEmpty == false ? "\(foodKind.title)：\(foodName ?? "")" : foodKind.title
        return PetEventDraft(
            kind: .daily,
            subkind: "feeding",
            title: "已喂",
            summary: "喂食：\(foodText)，份量：\(amount.title)\(noteText)",
            visibility: .private,
            occurredAt: PetWriteFormatters.occurredAtString(from: occurredAt),
            eventPayload: feedingEventPayload(trimmedNote: trimmedNote)
        )
    }

    private func feedingEventPayload(trimmedNote: String) -> [String: PetEventPayloadValue] {
        [
            "food_item_id": foodItemID.map(PetEventPayloadValue.string) ?? .null,
            "food_role": .string(foodKind.payloadRole),
            "amount_text": .string(amount.title),
            "food_snapshot": foodSnapshotPayload(),
            "is_default_food": .bool(isDefaultFood),
            "note": trimmedNote.isEmpty ? .null : .string(trimmedNote),
            "attachment_asset_ids": .stringArray(attachmentAssetIDs)
        ]
    }

    private func foodSnapshotPayload() -> PetEventPayloadValue {
        guard let foodSnapshotJSON,
              let data = foodSnapshotJSON.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return .null
        }
        return .object(object.compactMapValues(PetEventPayloadValue.init(jsonValue:)))
    }
}

private extension HomeQuickFactFeedingFoodKind {
    var payloadRole: String {
        switch self {
        case .mainFood:
            "main_food"
        case .wetFood:
            "wet_food"
        case .snack:
            "treats"
        case .supplement:
            "nutrition"
        case .other:
            "other"
        }
    }
}

private extension PetEventPayloadValue {
    init?(jsonValue: Any) {
        switch jsonValue {
        case let value as String:
            self = .string(value)
        case let value as Bool:
            self = .bool(value)
        case let value as [String]:
            self = .stringArray(value)
        case let value as [String: Any]:
            self = .object(value.compactMapValues(PetEventPayloadValue.init(jsonValue:)))
        case _ as NSNull:
            self = .null
        default:
            return nil
        }
    }
}
