import SwiftUI
import MaohuobanDesignSystem

// Internal: extracted from PetRecordHistoryScreen

// PetRecordHistoryItem 记录历史条目
// 核心职责：
// - 承载宠物记录列表中单条记录的展示数据
// - 提供从当前记录到详情页的路由构造
struct PetRecordHistoryItem: Identifiable, Hashable {
    let id: String
    let yearText: String
    let monthText: String
    let dateText: String
    let timeText: String
    let title: String
    let subtitle: String
    let kindText: String
    let systemImage: String
    let tint: Color

    var detailRoute: PetRecordDetailRoute {
        PetRecordDetailRoute.mockRoute(for: id)
    }

    static let mockItems: [PetRecordHistoryItem] = [
        PetRecordHistoryItem(
            id: "record-2026-06-feeding",
            yearText: "2026年",
            monthText: "6月",
            dateText: "6月24日",
            timeText: "08:30",
            title: "已喂食",
            subtitle: "主粮 · 正常",
            kindText: "喂食",
            systemImage: "fork.knife",
            tint: Color(mhbHex: "0093DD")
        ),
        PetRecordHistoryItem(
            id: "record-2026-06-weight",
            yearText: "2026年",
            monthText: "6月",
            dateText: "6月24日",
            timeText: "09:15",
            title: "体重更新",
            subtitle: "4.20 kg，较上次 -0.15 kg",
            kindText: "体重",
            systemImage: "scalemass.fill",
            tint: Color(mhbHex: "7C3AED")
        ),
        PetRecordHistoryItem(
            id: "record-2026-06-abnormal",
            yearText: "2026年",
            monthText: "6月",
            dateText: "6月24日",
            timeText: "20:15",
            title: "异常记录",
            subtitle: "食欲、精神 · 明显",
            kindText: "异常",
            systemImage: "cross.case.fill",
            tint: MHBTheme.ColorToken.danger.color
        ),
        PetRecordHistoryItem(
            id: "record-2026-06-deworming",
            yearText: "2026年",
            monthText: "6月",
            dateText: "6月22日",
            timeText: "11:30",
            title: "完成驱虫",
            subtitle: "大宠爱体外驱虫滴剂",
            kindText: "驱虫",
            systemImage: "checkmark.seal.fill",
            tint: Color(mhbHex: "0EA5E9")
        ),
        PetRecordHistoryItem(
            id: "record-2026-05-walk",
            yearText: "2026年",
            monthText: "5月",
            dateText: "5月20日",
            timeText: "20:20",
            title: "夜间散步",
            subtitle: "32 分钟 · 2.3 km",
            kindText: "遛弯",
            systemImage: "figure.walk",
            tint: Color(mhbHex: "F97316")
        ),
        PetRecordHistoryItem(
            id: "record-2026-05-appetite",
            yearText: "2026年",
            monthText: "5月",
            dateText: "5月18日",
            timeText: "19:10",
            title: "食欲正常",
            subtitle: "晚餐吃完，精神状态稳定",
            kindText: "事实",
            systemImage: "heart.text.square.fill",
            tint: Color(mhbHex: "16A34A")
        ),
        PetRecordHistoryItem(
            id: "record-2026-04-hospital",
            yearText: "2026年",
            monthText: "4月",
            dateText: "4月15日",
            timeText: "10:40",
            title: "医院体检",
            subtitle: "基础血常规与生化筛查",
            kindText: "就诊",
            systemImage: "stethoscope",
            tint: Color(mhbHex: "2563EB")
        )
    ]
}
