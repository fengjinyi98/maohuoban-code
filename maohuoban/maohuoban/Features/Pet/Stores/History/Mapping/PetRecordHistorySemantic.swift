import SwiftUI
import MaohuobanDesignSystem

// PetRecordHistorySemantic 记录历史语义解析
// 核心职责：
// - 将统一时间线条目归类为列表展示类型
// - 为真实事件生成对应详情路由
struct PetRecordHistorySemantic {
    private let entry: PetTimelineEntry

    init(entry: PetTimelineEntry) {
        self.entry = entry
    }

    var kindText: String {
        switch semantic {
        case .birth, .homecoming:
            "关键时刻"
        case .feeding:
            "喂食"
        case .poopNormal, .energyNormal, .appetiteNormal:
            "快速记录"
        case .weight:
            "体重"
        case .deworming:
            "驱虫"
        case .walk:
            "遛弯"
        case .vaccine:
            "疫苗"
        case .abnormal:
            "异常"
        case .clinicVisit:
            "就诊"
        case .unsupported:
            "记录"
        }
    }

    var systemImage: String {
        switch semantic {
        case .birth:
            "sparkles"
        case .homecoming:
            "house.fill"
        case .feeding:
            "fork.knife"
        case .poopNormal:
            "checkmark.seal.fill"
        case .energyNormal:
            "face.smiling"
        case .appetiteNormal:
            "takeoutbag.and.cup.and.straw.fill"
        case .weight:
            "scalemass.fill"
        case .deworming:
            "pills.fill"
        case .walk:
            "figure.walk"
        case .vaccine:
            "syringe.fill"
        case .abnormal:
            "exclamationmark.triangle.fill"
        case .clinicVisit:
            "stethoscope"
        case .unsupported:
            "doc.text.fill"
        }
    }

    var tint: Color {
        switch semantic {
        case .birth, .homecoming:
            MHBTheme.ColorToken.success.color
        case .feeding, .appetiteNormal:
            MHBTheme.ColorToken.warning.color
        case .poopNormal:
            MHBTheme.ColorToken.teal.color
        case .energyNormal:
            MHBTheme.ColorToken.primary.color
        case .weight:
            MHBTheme.ColorToken.primary.color
        case .deworming, .vaccine, .clinicVisit:
            MHBTheme.ColorToken.primary.color
        case .walk:
            MHBTheme.ColorToken.success.color
        case .abnormal:
            MHBTheme.ColorToken.danger.color
        case .unsupported:
            MHBTheme.ColorToken.labelSecondary.color
        }
    }

    func route(recordID: String, context: PetRecordEntryContext) -> PetRecordDetailRoute? {
        switch semantic {
        case .birth, .homecoming:
            nil
        case .feeding:
            .feeding(recordID: recordID, context: context)
        case .poopNormal:
            .quickFact(recordID: recordID, kind: .poopNormal, context: context)
        case .energyNormal:
            .quickFact(recordID: recordID, kind: .energyNormal, context: context)
        case .appetiteNormal:
            .quickFact(recordID: recordID, kind: .appetiteNormal, context: context)
        case .weight:
            .weight(recordID: recordID, context: context)
        case .deworming:
            .deworming(recordID: recordID, context: context)
        case .walk:
            .walk(recordID: recordID)
        case .vaccine:
            .vaccine(recordID: recordID, context: context)
        case .abnormal:
            .abnormal(recordID: recordID, context: context)
        case .clinicVisit:
            .clinicVisit(recordID: recordID)
        case .unsupported:
            .unsupported(recordID: recordID)
        }
    }

    private var semantic: HomeTimelineRecordSemantic {
        if entry.id.hasSuffix("-birth") || entry.subkind == "birth" {
            return .birth
        }
        if entry.id.hasSuffix("-homecoming") || entry.subkind == "homecoming" {
            return .homecoming
        }
        if entry.kind == .health, entry.subkind == "weight" {
            return .weight
        }
        if entry.kind == .health, entry.subkind == "vaccine" {
            return .vaccine
        }
        if entry.kind == .health, entry.subkind == "deworming" {
            return .deworming
        }

        return inferredSemantic
    }

    private var inferredSemantic: HomeTimelineRecordSemantic {
        let combinedText = "\(entry.title) \(entry.summary ?? "")"

        if entry.title.contains("喂") || combinedText.contains("喂食") {
            return .feeding
        }
        if entry.kind == .health, combinedText.contains("异常") {
            return .abnormal
        }
        if entry.kind == .health, combinedText.contains("就诊") || combinedText.contains("医院") {
            return .clinicVisit
        }
        if combinedText.contains("便便") || combinedText.contains("粪便") || combinedText.contains("排便") {
            return .poopNormal
        }
        if combinedText.contains("精神") || combinedText.contains("活力") {
            return .energyNormal
        }
        if combinedText.contains("食欲") {
            return .appetiteNormal
        }
        if entry.kind == .daily, combinedText.contains("散步") || combinedText.contains("遛弯") {
            return .walk
        }

        return .unsupported
    }
}
