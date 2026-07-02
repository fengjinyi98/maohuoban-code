import Foundation
import SwiftUI
import MaohuobanDesignSystem

// PetPreventiveCareContext 疫苗驱虫入口上下文
// 核心职责：
// - 承载首页 state 卡片进入疫苗/驱虫页面所需的宠物上下文
// - 保留记录流程可复用的宠物切换数据
struct PetPreventiveCareContext: Hashable, Sendable {
    let recordContext: PetRecordEntryContext
    let fallbackPetName: String
}

// PetPreventiveCareKind 疫苗驱虫记录类型
// 核心职责：
// - 区分疫苗和驱虫两类预防护理记录
// - 为筛选、图标和状态颜色提供稳定语义
enum PetPreventiveCareKind: String, CaseIterable, Hashable, Identifiable {
    case all
    case vaccine
    case deworming

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "全部"
        case .vaccine: "疫苗"
        case .deworming: "驱虫"
        }
    }

    var recordTitle: String {
        switch self {
        case .all: "预防护理"
        case .vaccine: "疫苗"
        case .deworming: "驱虫"
        }
    }

    var systemImage: String {
        switch self {
        case .all: "checklist"
        case .vaccine: "syringe"
        case .deworming: "shield.lefthalf.filled"
        }
    }

    var tint: Color {
        switch self {
        case .all: MHBTheme.ColorToken.primary.color
        case .vaccine: MHBTheme.ColorToken.primary.color
        case .deworming: MHBTheme.ColorToken.success.color
        }
    }
}

// PetPreventiveCareRecord 疫苗驱虫记录展示模型
// 核心职责：
// - 承载快速 UI 阶段的疫苗/驱虫 mock 记录
// - 为顶部状态、计划摘要和历史列表提供统一输入
struct PetPreventiveCareRecord: Identifiable, Hashable {
    let id: String
    let kind: PetPreventiveCareKind
    let title: String
    let subtitle: String
    let dateText: String
    let yearText: String
    let monthText: String
    let nextDueText: String?
    let daysDelta: Int?
    let status: Status

    enum Status: Hashable {
        case normal
        case dueSoon
        case overdue

        var title: String {
            switch self {
            case .normal: "已完成"
            case .dueSoon: "即将到期"
            case .overdue: "已过期"
            }
        }

        var tint: Color {
            switch self {
            case .normal: MHBTheme.ColorToken.success.color
            case .dueSoon: MHBTheme.ColorToken.warning.color
            case .overdue: MHBTheme.ColorToken.danger.color
            }
        }
    }

    static let mockRecords: [PetPreventiveCareRecord] = [
        PetPreventiveCareRecord(
            id: "vaccine-rabies-2026-06",
            kind: .vaccine,
            title: "狂犬疫苗",
            subtitle: "年度加强",
            dateText: "6月20日",
            yearText: "2026年",
            monthText: "6月",
            nextDueText: "2026.06.28",
            daysDelta: 3,
            status: .dueSoon
        ),
        PetPreventiveCareRecord(
            id: "deworming-2026-06",
            kind: .deworming,
            title: "体内驱虫",
            subtitle: "拜宠清",
            dateText: "6月10日",
            yearText: "2026年",
            monthText: "6月",
            nextDueText: "2026.07.10",
            daysDelta: 15,
            status: .normal
        ),
        PetPreventiveCareRecord(
            id: "vaccine-triple-2026-05",
            kind: .vaccine,
            title: "猫三联",
            subtitle: "妙三多 第 3 针",
            dateText: "5月18日",
            yearText: "2026年",
            monthText: "5月",
            nextDueText: "2027.05.18",
            daysDelta: 327,
            status: .normal
        ),
        PetPreventiveCareRecord(
            id: "deworming-2026-04",
            kind: .deworming,
            title: "内外同驱",
            subtitle: "大宠爱",
            dateText: "4月12日",
            yearText: "2026年",
            monthText: "4月",
            nextDueText: "2026.05.12",
            daysDelta: -44,
            status: .overdue
        )
    ]
}

