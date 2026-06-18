import Foundation

// PetWorldFeedPage 内容页展示模型
// 核心职责：
// - 承载单个频道页的筛选提示和卡片列表
// - 为 SwiftUI 页面和 UIKit 分页容器提供稳定输入
struct PetWorldFeedPage {
    let tab: PetWorldFeedTab
    let hintChips: [String]
    let items: [PetWorldFeedItem]
}

// PetWorldFeedPageContentResolver 宠物世界频道内容解析器
// 核心职责：
// - 将 Feed 快照解析为各频道可展示内容
// - 在真实接口接入前保持横滑分页内容差异可验证
enum PetWorldFeedPageContentResolver {
    static func page(
        for tab: PetWorldFeedTab,
        snapshot: PetWorldFeedSnapshot
    ) -> PetWorldFeedPage {
        switch tab {
        case .recommended:
            PetWorldFeedPage(
                tab: tab,
                hintChips: snapshot.hintChips,
                items: snapshot.items
            )
        case .following:
            PetWorldFeedPage(
                tab: tab,
                hintChips: ["已关注", "近期更新", "猫咪动态"],
                items: followingItems(from: snapshot.items)
            )
        case .growth:
            PetWorldFeedPage(
                tab: tab,
                hintChips: ["成长记录", "阶段相近", "到家适应"],
                items: growthItems(from: snapshot.items)
            )
        case .experience:
            PetWorldFeedPage(
                tab: tab,
                hintChips: ["优质经验", "护理技巧", "可收藏"],
                items: experienceItems(from: snapshot.items)
            )
        }
    }

    private static func followingItems(from items: [PetWorldFeedItem]) -> [PetWorldFeedItem] {
        items.filter { item in
            item.pet.systemImage == "cat.fill"
        }
    }

    private static func growthItems(from items: [PetWorldFeedItem]) -> [PetWorldFeedItem] {
        let promotedItems = items.filter { item in
            item.badge.style == .growth
        }
        let relatedItems = items.filter { item in
            item.topics.contains("幼猫成长")
        }

        return promotedItems + relatedItems
    }

    private static func experienceItems(from items: [PetWorldFeedItem]) -> [PetWorldFeedItem] {
        let promotedItems = items.filter { item in
            item.badge.style == .quality || item.badge.style == .experience
        }
        let relatedItems = items.filter { item in
            item.topics.contains("换粮")
        }

        return promotedItems + relatedItems
    }
}
