import SwiftUI
import MaohuobanDesignSystem

// HomeQuickFactFeedingFoodSource 喂食储物柜数据源
// 核心职责：
// - 将储物柜分类映射到快捷喂食分类
// - 提供默认物品和选中物品名称解析
enum HomeQuickFactFeedingFoodSource {
    static func items(
        for kind: HomeQuickFactFeedingFoodKind,
        in options: [HomeQuickFactFeedingFoodOption]
    ) -> [HomeQuickFactFeedingFoodOption] {
        options.filter { $0.kind == kind }
    }

    static func defaultItemID(
        for kind: HomeQuickFactFeedingFoodKind,
        in options: [HomeQuickFactFeedingFoodOption]
    ) -> String? {
        defaultItem(for: kind, in: options)?.id
    }

    static func defaultItemName(
        for kind: HomeQuickFactFeedingFoodKind,
        in options: [HomeQuickFactFeedingFoodOption]
    ) -> String? {
        defaultItem(for: kind, in: options)?.name
    }

    static func itemName(
        for itemID: String?,
        in kind: HomeQuickFactFeedingFoodKind,
        options: [HomeQuickFactFeedingFoodOption]
    ) -> String? {
        item(for: itemID, in: kind, options: options)?.name
    }

    static func selectedItemID(
        for kind: HomeQuickFactFeedingFoodKind,
        selectedItemIDs: [HomeQuickFactFeedingFoodKind: String?],
        options: [HomeQuickFactFeedingFoodOption]
    ) -> String? {
        if let selectedItemID = selectedItemIDs[kind] {
            return selectedItemID
        }
        return defaultItemID(for: kind, in: options)
    }

    static func syncedSelectedItemID(
        for kind: HomeQuickFactFeedingFoodKind,
        currentSelectedItemID: String?,
        previousDefaultItemID: String?,
        isManualSelection: Bool,
        options: [HomeQuickFactFeedingFoodOption]
    ) -> String? {
        let kindItems = items(for: kind, in: options)
        let newDefaultItemID = defaultItemID(for: kind, in: options)
        let hasCurrentSelection = currentSelectedItemID.map { selectedID in
            kindItems.contains { $0.id == selectedID }
        } ?? false

        if isManualSelection, hasCurrentSelection {
            return currentSelectedItemID
        }
        if currentSelectedItemID == nil || currentSelectedItemID == previousDefaultItemID || !hasCurrentSelection {
            return newDefaultItemID
        }
        return currentSelectedItemID
    }

    static func hasSelectionEntry(
        for kind: HomeQuickFactFeedingFoodKind,
        selectedItemIDs: [HomeQuickFactFeedingFoodKind: String?]
    ) -> Bool {
        selectedItemIDs.keys.contains(kind)
    }

    static func item(
        for itemID: String?,
        in kind: HomeQuickFactFeedingFoodKind,
        options: [HomeQuickFactFeedingFoodOption]
    ) -> HomeQuickFactFeedingFoodOption? {
        guard let itemID else { return nil }
        return items(for: kind, in: options).first { $0.id == itemID }
    }

    private static func defaultItem(
        for kind: HomeQuickFactFeedingFoodKind,
        in options: [HomeQuickFactFeedingFoodOption]
    ) -> HomeQuickFactFeedingFoodOption? {
        let items = items(for: kind, in: options)
        return items.first { $0.isDefault } ?? items.first
    }
}

extension HomeQuickFactFeedingFoodKind {
    var emptySelectionTitle: String {
        switch self {
        case .mainFood:
            "选择主粮"
        case .snack:
            "选择零食"
        case .supplement:
            "选择营养品"
        case .other:
            "在备注中补充"
        }
    }
}

extension PantryCategory {
    var feedingKind: HomeQuickFactFeedingFoodKind? {
        switch self {
        case .mainFood, .wetFood:
            .mainFood
        case .treats:
            .snack
        case .supplements:
            .supplement
        case .other:
            .other
        case .all, .catLitter, .medicine:
            nil
        }
    }

    var feedingSystemImage: String {
        switch self {
        case .mainFood, .wetFood:
            HomeQuickFactFeedingFoodKind.mainFood.systemImage
        case .treats:
            HomeQuickFactFeedingFoodKind.snack.systemImage
        case .supplements:
            HomeQuickFactFeedingFoodKind.supplement.systemImage
        case .other:
            HomeQuickFactFeedingFoodKind.other.systemImage
        case .all:
            "tray.full.fill"
        case .catLitter:
            "drop.fill"
        case .medicine:
            "pills.fill"
        }
    }
}
