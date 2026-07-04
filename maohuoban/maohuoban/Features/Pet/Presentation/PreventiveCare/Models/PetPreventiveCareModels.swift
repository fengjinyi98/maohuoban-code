import Foundation
import SwiftUI
import MaohuobanDesignSystem

// PetPreventiveCareContext 疫苗驱虫入口上下文
// 核心职责：
// - 承载首页 state 卡片进入疫苗/驱虫页面所需的宠物上下文
// - 保留记录流程可复用的宠物切换数据
struct PetPreventiveCareContext: Hashable, Sendable {
    let recordContext: PetRecordEntryContext
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

    init?(eventSubkind: String?) {
        switch eventSubkind {
        case "vaccine":
            self = .vaccine
        case "deworming":
            self = .deworming
        default:
            return nil
        }
    }
}

// PetPreventiveCareRecord 疫苗驱虫记录展示模型
// 核心职责：
// - 承载后端疫苗/驱虫事件投影
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
    let completedAt: Date
    let nextDueAt: Date?
    let executionMethodRawValue: String?
    let executionName: String?
    let note: String?
    let attachmentAssetIDs: [String]

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

}
