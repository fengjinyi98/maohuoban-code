import Foundation

// HomeQuickFactFeedingFoodOption 喂食食品选项
// 核心职责：
// - 表达快捷喂食 sheet 可选择的储物柜食品资产
// - 生成带食品资产引用和当时快照的喂食输入
struct HomeQuickFactFeedingFoodOption: Identifiable, Equatable {
    let id: String
    let kind: HomeQuickFactFeedingFoodKind
    let name: String
    let brand: String?
    let category: String
    let spec: String?
    let unit: String?
    let imageURL: String?
    let isDefault: Bool

    init(
        id: String,
        kind: HomeQuickFactFeedingFoodKind,
        name: String,
        brand: String?,
        category: String,
        spec: String?,
        unit: String? = nil,
        imageURL: String?,
        isDefault: Bool
    ) {
        self.id = id
        self.kind = kind
        self.name = name
        self.brand = brand
        self.category = category
        self.spec = spec
        self.unit = unit
        self.imageURL = imageURL
        self.isDefault = isDefault
    }

    init?(foodInventoryItem item: FoodInventoryItem, isDefault: Bool = false) {
        guard let kind = HomeQuickFactFeedingFoodKind(foodInventoryCategory: item.category) else {
            return nil
        }
        self.init(
            id: item.id,
            kind: kind,
            name: item.name,
            brand: item.brand,
            category: item.category.rawValue,
            spec: item.spec,
            unit: item.unit,
            imageURL: item.coverURL,
            isDefault: isDefault
        )
    }

    var displayBrand: String {
        brand?.isEmpty == false ? brand ?? "储物柜食品" : "储物柜食品"
    }

    var statusLabel: String {
        isDefault ? "当前默认" : "储物柜"
    }

    var systemImage: String {
        kind.systemImage
    }

    func feedingInput(
        petID: String?,
        lifeStatus: String?,
        amount: HomeQuickFactFeedingAmount,
        occurredAt: Date,
        note: String,
        attachmentAssetIDs: [String]
    ) -> HomeQuickFactFeedingInput {
        HomeQuickFactFeedingInput(
            petID: petID,
            lifeStatus: lifeStatus,
            foodKind: kind,
            foodName: name,
            foodItemID: id,
            foodSnapshotJSON: foodSnapshotJSON(),
            isDefaultFood: isDefault,
            amount: amount,
            occurredAt: occurredAt,
            note: note,
            attachmentAssetIDs: attachmentAssetIDs
        )
    }

    private func foodSnapshotJSON() -> String? {
        var snapshot: [String: String] = [
            "name": name,
            "category": category
        ]
        if let brand, !brand.isEmpty {
            snapshot["brand"] = brand
        }
        if let spec, !spec.isEmpty {
            snapshot["spec"] = spec
        }
        if let unit, !unit.isEmpty {
            snapshot["unit"] = unit
        }
        if let imageURL, !imageURL.isEmpty {
            snapshot["cover_url"] = imageURL
        }
        guard let data = try? JSONSerialization.data(withJSONObject: snapshot),
              let json = String(data: data, encoding: .utf8)
        else {
            return nil
        }
        return json
    }
}

private extension HomeQuickFactFeedingFoodKind {
    init?(foodInventoryCategory: FoodInventoryCategory) {
        switch foodInventoryCategory {
        case .mainFood:
            self = .mainFood
        case .wetFood:
            self = .wetFood
        case .treats:
            self = .snack
        case .nutrition:
            self = .supplement
        case .other:
            self = .other
        case .catLitter, .medicine:
            return nil
        }
    }
}
