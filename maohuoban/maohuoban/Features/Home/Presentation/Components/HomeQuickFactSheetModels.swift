import Foundation

// HomeQuickFactSheet 快捷事实弹层类型
// 核心职责：
// - 区分需要补充上下文的快捷动作
// - 为 sheet(item:) 提供稳定身份
enum HomeQuickFactSheet: String, Identifiable {
    case feeding
    case abnormal

    var id: String { rawValue }
}

// HomeQuickFactFeedingFoodKind 喂食食品类型
// 核心职责：
// - 承载喂食 sheet 中的食品粗分类
// - 为后续接入食品库保留稳定语义
enum HomeQuickFactFeedingFoodKind: String, CaseIterable, Identifiable {
    case mainFood
    case snack
    case supplement
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mainFood: "主粮"
        case .snack: "零食"
        case .supplement: "补剂"
        case .other: "其他"
        }
    }

    var systemImage: String {
        switch self {
        case .mainFood: "takeoutbag.and.cup.and.straw.fill"
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
    let foodKind: HomeQuickFactFeedingFoodKind
    let amount: HomeQuickFactFeedingAmount
    let note: String

    func eventDraft(occurredAt: Date) -> PetEventDraft {
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let noteText = trimmedNote.isEmpty ? "" : "，备注：\(trimmedNote)"
        return PetEventDraft(
            kind: .daily,
            subkind: "feeding",
            title: "已喂",
            summary: "喂食：\(foodKind.title)，份量：\(amount.title)\(noteText)",
            visibility: .private,
            occurredAt: PetWriteFormatters.occurredAtString(from: occurredAt)
        )
    }
}

// HomeQuickFactAbnormalSymptom 异常快捷记录症状
// 核心职责：
// - 承载异常 sheet 的症状多选项
// - 为症状链事件提供初始结构化线索
enum HomeQuickFactAbnormalSymptom: String, CaseIterable, Identifiable {
    case appetite
    case energy
    case stool
    case vomit
    case cough
    case skin
    case walk
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .appetite: "食欲"
        case .energy: "精神"
        case .stool: "便便"
        case .vomit: "呕吐"
        case .cough: "咳嗽"
        case .skin: "皮肤"
        case .walk: "走路"
        case .other: "其他"
        }
    }

    var systemImage: String {
        switch self {
        case .appetite: "fork.knife.circle.fill"
        case .energy: "face.dashed.fill"
        case .stool: "exclamationmark.triangle.fill"
        case .vomit: "drop.triangle.fill"
        case .cough: "lungs.fill"
        case .skin: "bandage.fill"
        case .walk: "figure.walk.motion"
        case .other: "questionmark.circle.fill"
        }
    }
}

// HomeQuickFactAbnormalSeverity 异常严重程度
// 核心职责：
// - 表达用户对异常程度的初步判断
// - 为后续风险提示和追踪提供分层输入
enum HomeQuickFactAbnormalSeverity: String, CaseIterable, Identifiable {
    case mild
    case obvious
    case severe

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mild: "轻微"
        case .obvious: "明显"
        case .severe: "严重"
        }
    }
}

// HomeQuickFactAbnormalInput 异常快捷记录输入
// 核心职责：
// - 汇总异常 sheet 的提交数据
// - 转换为现有宠物事件草稿
struct HomeQuickFactAbnormalInput: Equatable {
    let petID: String?
    let symptoms: [HomeQuickFactAbnormalSymptom]
    let severity: HomeQuickFactAbnormalSeverity
    let note: String

    func eventDraft(occurredAt: Date) -> PetEventDraft {
        let symptomsText = symptoms.map(\.title).joined(separator: "、")
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let noteText = trimmedNote.isEmpty ? "" : "，备注：\(trimmedNote)"
        return PetEventDraft(
            kind: .health,
            subkind: "quick_abnormal",
            title: "异常记录",
            summary: "异常：\(symptomsText)，程度：\(severity.title)\(noteText)",
            visibility: .private,
            occurredAt: PetWriteFormatters.occurredAtString(from: occurredAt)
        )
    }
}
