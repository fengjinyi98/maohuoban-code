import Foundation
import Observation

// PetWorldFeedInteractionStore 宠物世界 Feed 互动状态源
// 核心职责：
// - 统一管理 Feed 与后续详情页共享的点赞状态
// - 通过显式用户事件更新点赞状态和计数
@MainActor
@Observable
final class PetWorldFeedInteractionStore {
    private var interactionsByCardID: [String: PetWorldFeedInteractionState]

    init(cards: [PetWorldFeedItem]) {
        interactionsByCardID = Dictionary(
            uniqueKeysWithValues: cards.map { card in
                (
                    card.id,
                    PetWorldFeedInteractionState(
                        isLiked: card.isLiked,
                        likeCount: card.likeCount
                    )
                )
            }
        )
    }

    // interactionState 读取指定卡片互动状态
    // 核心职责：
    // - 为列表卡片提供 Store 中的最新点赞快照
    // - 在缺失状态时回退到卡片初始展示数据
    func interactionState(for card: PetWorldFeedItem) -> PetWorldFeedInteractionState {
        interactionsByCardID[card.id] ?? PetWorldFeedInteractionState(
            isLiked: card.isLiked,
            likeCount: card.likeCount
        )
    }

    // toggleLike 切换指定卡片点赞状态
    // 核心职责：
    // - 响应用户点赞点击事件
    // - 保证点赞计数随状态切换同步更新
    func toggleLike(cardID: String) {
        guard let currentState = interactionsByCardID[cardID] else {
            return
        }

        let nextIsLiked = !currentState.isLiked
        let nextLikeCount = max(
            0,
            currentState.likeCount + (nextIsLiked ? 1 : -1)
        )

        interactionsByCardID[cardID] = PetWorldFeedInteractionState(
            isLiked: nextIsLiked,
            likeCount: nextLikeCount
        )
    }
}
