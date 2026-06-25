import Foundation

// PetPantryDietSummaryRow 储物柜饮食摘要行
// 核心职责：
// - 将宠物饮食配置强事实转换为储物柜首页摘要
// - 保持展示层只读取已整理好的标题和值
struct PetPantryDietSummaryRow: Equatable, Identifiable {
    let id: String
    let title: String
    let value: String

    static func rows(from context: PetCurrentDietContext) -> [PetPantryDietSummaryRow] {
        var rows: [PetPantryDietSummaryRow] = []
        if let currentStaple = context.currentStaple {
            rows.append(
                PetPantryDietSummaryRow(
                    id: "current_staple",
                    title: "当前主粮",
                    value: currentStaple.foodName
                )
            )
        }
        if !context.tryingFoods.isEmpty {
            rows.append(
                PetPantryDietSummaryRow(
                    id: "trying",
                    title: "尝试中",
                    value: context.tryingFoods.map(\.foodName).joined(separator: "、")
                )
            )
        }
        if !context.usualTreats.isEmpty {
            rows.append(
                PetPantryDietSummaryRow(
                    id: "usual_treats",
                    title: "常用零食",
                    value: context.usualTreats.map(\.foodName).joined(separator: "、")
                )
            )
        }
        if !context.usualNutritions.isEmpty {
            rows.append(
                PetPantryDietSummaryRow(
                    id: "usual_nutritions",
                    title: "常用营养品",
                    value: context.usualNutritions.map(\.foodName).joined(separator: "、")
                )
            )
        }
        return rows
    }
}
