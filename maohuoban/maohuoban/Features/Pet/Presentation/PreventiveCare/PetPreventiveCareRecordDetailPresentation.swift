import SwiftUI
import MaohuobanDesignSystem

// PetPreventiveCareRecordDetailPresentation 疫苗驱虫详情展示模型
// 核心职责：
// - 提供快速 UI 阶段的疫苗驱虫详情 mock 数据
// - 将同一详情页按记录类型映射出不同字段文案
struct PetPreventiveCareRecordDetailPresentation {
    struct PetIdentity: Equatable {
        let id: String
        let name: String
        let avatarSource: MHBAvatarSource

        var avatarPet: MHBAvatarPet {
            MHBAvatarPet(
                id: id,
                name: name,
                source: avatarSource,
                species: .other,
                sex: .unknown
            )
        }
    }

    struct InfoRow: Identifiable, Equatable {
        let id: String
        let title: String
        let value: String
    }

    struct PhotoItem: Identifiable, Equatable {
        let id: String
        let title: String
        let systemImage: String
        let tint: Color
    }

    struct RelatedRecord: Identifiable, Equatable {
        let id: String
        let title: String
        let subtitle: String
        let dateText: String
        let isCurrent: Bool
    }

    let recordID: String
    let kind: PetPreventiveCareKind
    let title: String
    let completedAtText: String
    let statusTitle: String
    let statusDescription: String
    let statusSystemImage: String
    let statusTint: Color
    let pet: PetIdentity
    let infoRows: [InfoRow]
    let reminderRows: [InfoRow]
    let note: String
    let photoItems: [PhotoItem]
    let relatedRecords: [RelatedRecord]

    var navigationTitle: String {
        "\(kind.recordTitle)详情"
    }

    static func mock(
        recordID: String,
        fallbackKind: PetPreventiveCareKind
    ) -> PetPreventiveCareRecordDetailPresentation {
        let data = PetPreventiveCareRecordDetailMockData.record(
            for: recordID,
            fallbackKind: fallbackKind
        )
        let pet = PetIdentity(
            id: "pet-preventive-record-mock",
            name: "测试名字1",
            avatarSource: .asset("HomePetHeroMock")
        )

        return PetPreventiveCareRecordDetailPresentation(
            recordID: recordID,
            kind: data.kind,
            title: data.title,
            completedAtText: data.completedAtText,
            statusTitle: data.statusTitle,
            statusDescription: data.statusDescription,
            statusSystemImage: data.statusSystemImage,
            statusTint: data.statusTint,
            pet: pet,
            infoRows: data.infoRows,
            reminderRows: data.reminderRows,
            note: data.note,
            photoItems: data.photoItems,
            relatedRecords: data.relatedRecords
        )
    }
}

// PetPreventiveCareRecordDetailMockData 疫苗驱虫详情 mock 数据
// 核心职责：
// - 按记录 ID 返回不同疫苗驱虫详情样例
// - 覆盖首页时间线、全部记录和预防护理历史列表的 mock 路由
private struct PetPreventiveCareRecordDetailMockData {
    typealias InfoRow = PetPreventiveCareRecordDetailPresentation.InfoRow
    typealias PhotoItem = PetPreventiveCareRecordDetailPresentation.PhotoItem
    typealias RelatedRecord = PetPreventiveCareRecordDetailPresentation.RelatedRecord

    let kind: PetPreventiveCareKind
    let title: String
    let completedAtText: String
    let statusTitle: String
    let statusDescription: String
    let statusSystemImage: String
    let statusTint: Color
    let infoRows: [InfoRow]
    let reminderRows: [InfoRow]
    let note: String
    let photoItems: [PhotoItem]
    let relatedRecords: [RelatedRecord]

    static func record(
        for recordID: String,
        fallbackKind: PetPreventiveCareKind
    ) -> PetPreventiveCareRecordDetailMockData {
        switch recordID {
        case "vaccine-rabies-2026-06", "record-2026-06-vaccine", "event-vaccine":
            rabiesVaccine
        case "vaccine-triple-2026-05":
            tripleVaccine
        case "deworming-2026-06", "record-2026-06-deworming", "event-deworming":
            internalDeworming
        case "deworming-2026-04":
            combinedDeworming
        default:
            fallbackKind == .deworming ? internalDeworming : rabiesVaccine
        }
    }

    private static let rabiesVaccine = PetPreventiveCareRecordDetailMockData(
        kind: .vaccine,
        title: "狂犬疫苗",
        completedAtText: "2026年6月20日",
        statusTitle: "即将到期",
        statusDescription: "下次提醒：2026.06.28 · 距疫苗 3 天",
        statusSystemImage: "bell.badge.fill",
        statusTint: MHBTheme.ColorToken.warning.color,
        infoRows: [
            InfoRow(id: "type", title: "类型", value: "疫苗"),
            InfoRow(id: "name", title: "名称", value: "狂犬疫苗"),
            InfoRow(id: "date", title: "完成日期", value: "2026年6月20日"),
            InfoRow(id: "method", title: "执行方式", value: "医院完成"),
            InfoRow(id: "subject", title: "医院", value: "瑞派宠物医院")
        ],
        reminderRows: [
            InfoRow(id: "enabled", title: "提醒", value: "已开启"),
            InfoRow(id: "date", title: "提醒日期", value: "2026年6月28日"),
            InfoRow(id: "days", title: "距离到期", value: "3 天")
        ],
        note: "年度加强针，医院已在疫苗本盖章。接种后当天精神状态正常。",
        photoItems: [
            PhotoItem(id: "book", title: "疫苗本", systemImage: "book.closed.fill", tint: MHBTheme.ColorToken.primary.color),
            PhotoItem(id: "receipt", title: "单据", systemImage: "doc.text.fill", tint: MHBTheme.ColorToken.teal.color)
        ],
        relatedRecords: [
            RelatedRecord(id: "current", title: "狂犬疫苗", subtitle: "年度加强", dateText: "当前", isCurrent: true),
            RelatedRecord(id: "triple", title: "猫三联", subtitle: "妙三多 第 3 针", dateText: "2026.05.18", isCurrent: false),
            RelatedRecord(id: "rabies-2025", title: "狂犬疫苗", subtitle: "年度加强", dateText: "2025.06.20", isCurrent: false)
        ]
    )

    private static let tripleVaccine = PetPreventiveCareRecordDetailMockData(
        kind: .vaccine,
        title: "猫三联",
        completedAtText: "2026年5月18日",
        statusTitle: "已完成",
        statusDescription: "下次提醒：2027.05.18 · 距疫苗 327 天",
        statusSystemImage: "checkmark.seal.fill",
        statusTint: MHBTheme.ColorToken.success.color,
        infoRows: [
            InfoRow(id: "type", title: "类型", value: "疫苗"),
            InfoRow(id: "name", title: "名称", value: "妙三多 第 3 针"),
            InfoRow(id: "date", title: "完成日期", value: "2026年5月18日"),
            InfoRow(id: "method", title: "执行方式", value: "医院完成"),
            InfoRow(id: "subject", title: "医院", value: "瑞派宠物医院")
        ],
        reminderRows: [
            InfoRow(id: "enabled", title: "提醒", value: "已开启"),
            InfoRow(id: "date", title: "提醒日期", value: "2027年5月18日"),
            InfoRow(id: "days", title: "距离到期", value: "327 天")
        ],
        note: "完成猫三联基础免疫最后一针，医生建议一年后加强。",
        photoItems: [
            PhotoItem(id: "book", title: "疫苗本", systemImage: "book.closed.fill", tint: MHBTheme.ColorToken.primary.color)
        ],
        relatedRecords: [
            RelatedRecord(id: "current", title: "猫三联", subtitle: "妙三多 第 3 针", dateText: "当前", isCurrent: true),
            RelatedRecord(id: "rabies", title: "狂犬疫苗", subtitle: "年度加强", dateText: "2026.06.20", isCurrent: false)
        ]
    )

    private static let internalDeworming = PetPreventiveCareRecordDetailMockData(
        kind: .deworming,
        title: "体内驱虫",
        completedAtText: "2026年6月10日",
        statusTitle: "已完成",
        statusDescription: "下次提醒：2026.07.10 · 距驱虫 15 天",
        statusSystemImage: "checkmark.seal.fill",
        statusTint: MHBTheme.ColorToken.success.color,
        infoRows: [
            InfoRow(id: "type", title: "类型", value: "驱虫"),
            InfoRow(id: "name", title: "名称", value: "拜宠清"),
            InfoRow(id: "date", title: "完成日期", value: "2026年6月10日"),
            InfoRow(id: "method", title: "执行方式", value: "自己完成"),
            InfoRow(id: "subject", title: "说明", value: "家里口服，按体重用量")
        ],
        reminderRows: [
            InfoRow(id: "enabled", title: "提醒", value: "已开启"),
            InfoRow(id: "date", title: "提醒日期", value: "2026年7月10日"),
            InfoRow(id: "days", title: "距离到期", value: "15 天")
        ],
        note: "饭后完成体内驱虫，后续观察排便状态。当前为 mock 数据。",
        photoItems: [
            PhotoItem(id: "box", title: "药盒", systemImage: "pills.fill", tint: MHBTheme.ColorToken.success.color)
        ],
        relatedRecords: [
            RelatedRecord(id: "current", title: "体内驱虫", subtitle: "拜宠清", dateText: "当前", isCurrent: true),
            RelatedRecord(id: "combined", title: "内外同驱", subtitle: "大宠爱", dateText: "2026.04.12", isCurrent: false)
        ]
    )

    private static let combinedDeworming = PetPreventiveCareRecordDetailMockData(
        kind: .deworming,
        title: "内外同驱",
        completedAtText: "2026年4月12日",
        statusTitle: "已过期",
        statusDescription: "下次提醒：2026.05.12 · 驱虫已过期 44 天",
        statusSystemImage: "exclamationmark.triangle.fill",
        statusTint: MHBTheme.ColorToken.danger.color,
        infoRows: [
            InfoRow(id: "type", title: "类型", value: "驱虫"),
            InfoRow(id: "name", title: "名称", value: "大宠爱"),
            InfoRow(id: "date", title: "完成日期", value: "2026年4月12日"),
            InfoRow(id: "method", title: "执行方式", value: "自己完成"),
            InfoRow(id: "subject", title: "说明", value: "滴剂，后颈部位")
        ],
        reminderRows: [
            InfoRow(id: "enabled", title: "提醒", value: "已开启"),
            InfoRow(id: "date", title: "提醒日期", value: "2026年5月12日"),
            InfoRow(id: "days", title: "当前状态", value: "已过期 44 天")
        ],
        note: "上次内外同驱记录，已超过计划提醒时间。",
        photoItems: [
            PhotoItem(id: "box", title: "药盒", systemImage: "shippingbox.fill", tint: MHBTheme.ColorToken.success.color)
        ],
        relatedRecords: [
            RelatedRecord(id: "internal", title: "体内驱虫", subtitle: "拜宠清", dateText: "2026.06.10", isCurrent: false),
            RelatedRecord(id: "current", title: "内外同驱", subtitle: "大宠爱", dateText: "当前", isCurrent: true)
        ]
    )
}
