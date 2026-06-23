import Foundation
import Observation

// FeedInteractionStore Feed 互动状态源
// 核心职责：
// - 统一管理 Feed 与后续详情页共享的点赞状态
// - 通过显式用户事件更新点赞状态和计数
@MainActor
@Observable
final class FeedInteractionStore {
    private var interactionsByPostID: [String: FeedInteractionState]
    private var commentsByPostID: [String: [FeedComment]] = [:]

    init(cards: [FeedItem]) {
        interactionsByPostID = Dictionary(
            uniqueKeysWithValues: cards.map { card in
                (
                    card.postID,
                    FeedInteractionState(
                        isLiked: card.isLiked,
                        likeCount: card.likeCount
                    )
                )
            }
        )
    }

    // interactionState 读取指定帖子互动状态
    // 核心职责：
    // - 为列表卡片提供 Store 中的最新点赞快照
    // - 在缺失状态时回退到帖子初始展示数据
    func interactionState(for card: FeedItem) -> FeedInteractionState {
        interactionsByPostID[card.postID] ?? FeedInteractionState(
            isLiked: card.isLiked,
            likeCount: card.likeCount
        )
    }

    // interactionState 读取指定帖子的互动状态
    // 核心职责：
    // - 为详情页提供 Store 中的最新点赞快照
    // - 在缺失状态时回退到详情 mock 的初始展示数据
    func interactionState(
        postID: String,
        fallbackIsLiked: Bool,
        fallbackLikeCount: Int
    ) -> FeedInteractionState {
        interactionsByPostID[postID] ?? FeedInteractionState(
            isLiked: fallbackIsLiked,
            likeCount: fallbackLikeCount
        )
    }

    // toggleLike 切换指定帖子点赞状态
    // 核心职责：
    // - 响应用户点赞点击事件
    // - 保证点赞计数随状态切换同步更新
    func toggleLike(postID: String) {
        guard let currentState = interactionsByPostID[postID] else {
            return
        }

        let nextIsLiked = !currentState.isLiked
        let nextLikeCount = max(
            0,
            currentState.likeCount + (nextIsLiked ? 1 : -1)
        )

        interactionsByPostID[postID] = FeedInteractionState(
            isLiked: nextIsLiked,
            likeCount: nextLikeCount
        )
    }

    // prepareCommentsIfNeeded 准备详情页评论树状态
    // 核心职责：
    // - 在显式生命周期边界安装评论初始快照
    // - 避免 SwiftUI 渲染读取路径写入 Store
    func prepareCommentsIfNeeded(
        postID: String,
        comments: [FeedComment]
    ) {
        guard commentsByPostID[postID] == nil else {
            return
        }

        commentsByPostID[postID] = comments
    }

    // comments 读取详情页评论树状态
    // 核心职责：
    // - 为详情页评论区提供最新评论树
    // - 在 Store 尚未安装时回退到详情初始评论
    func comments(
        postID: String,
        fallbackComments: [FeedComment]
    ) -> [FeedComment] {
        commentsByPostID[postID] ?? fallbackComments
    }

    // commentCount 读取详情页评论总数
    // 核心职责：
    // - 递归统计父评论和子评论数量
    // - 为底部操作栏评论计数提供同一状态源
    func commentCount(
        postID: String,
        fallbackComments: [FeedComment]
    ) -> Int {
        Self.totalCommentCount(
            in: comments(
                postID: postID,
                fallbackComments: fallbackComments
            )
        )
    }

    // toggleCommentLike 切换评论点赞状态
    // 核心职责：
    // - 响应评论区点赞点击事件
    // - 保持点赞状态和计数在评论树内同步更新
    func toggleCommentLike(postID: String, commentID: String) {
        guard let currentComments = commentsByPostID[postID] else {
            return
        }

        commentsByPostID[postID] = Self.updateComment(
            commentID: commentID,
            in: currentComments
        ) { comment in
            let nextIsLiked = !comment.isLiked
            return FeedComment(
                id: comment.id,
                authorName: comment.authorName,
                avatarAssetName: comment.avatarAssetName,
                text: comment.text,
                publishedAt: comment.publishedAt,
                isPostAuthor: comment.isPostAuthor,
                isOwnedByCurrentUser: comment.isOwnedByCurrentUser,
                isLiked: nextIsLiked,
                likeCount: max(0, comment.likeCount + (nextIsLiked ? 1 : -1)),
                replies: comment.replies,
                petName: comment.petName,
                petAvatarAssetName: comment.petAvatarAssetName
            )
        }
    }

    // addComment 添加根评论或回复
    // 核心职责：
    // - 根据 parentCommentID 决定插入到根列表或目标评论 replies
    // - 保持评论树数据在 Store 内单向更新
    func addComment(
        postID: String,
        parentCommentID: String?,
        comment: FeedComment
    ) {
        let currentComments = commentsByPostID[postID] ?? []
        guard let parentCommentID else {
            commentsByPostID[postID] = [comment] + currentComments
            return
        }

        commentsByPostID[postID] = Self.updateComment(
            commentID: parentCommentID,
            in: currentComments
        ) { parent in
            FeedComment(
                id: parent.id,
                authorName: parent.authorName,
                avatarAssetName: parent.avatarAssetName,
                text: parent.text,
                publishedAt: parent.publishedAt,
                isPostAuthor: parent.isPostAuthor,
                isOwnedByCurrentUser: parent.isOwnedByCurrentUser,
                isLiked: parent.isLiked,
                likeCount: parent.likeCount,
                replies: parent.replies + [comment],
                petName: parent.petName,
                petAvatarAssetName: parent.petAvatarAssetName
            )
        }
    }

    // deleteComment 删除指定评论节点
    // 核心职责：
    // - 删除本人评论及其子树
    // - 对非本人评论保持数据不变
    func deleteComment(postID: String, commentID: String) {
        guard let currentComments = commentsByPostID[postID],
              Self.comment(commentID: commentID, in: currentComments)?.isOwnedByCurrentUser == true
        else {
            return
        }

        commentsByPostID[postID] = Self.deleteComment(
            commentID: commentID,
            from: currentComments
        )
    }

    private static func totalCommentCount(in comments: [FeedComment]) -> Int {
        comments.reduce(0) { partialResult, comment in
            partialResult + 1 + totalCommentCount(in: comment.replies)
        }
    }

    private static func comment(
        commentID: String,
        in comments: [FeedComment]
    ) -> FeedComment? {
        for comment in comments {
            if comment.id == commentID {
                return comment
            }

            if let reply = Self.comment(commentID: commentID, in: comment.replies) {
                return reply
            }
        }

        return nil
    }

    private static func updateComment(
        commentID: String,
        in comments: [FeedComment],
        transform: (FeedComment) -> FeedComment
    ) -> [FeedComment] {
        comments.map { comment in
            if comment.id == commentID {
                return transform(comment)
            }

            let updatedReplies = updateComment(
                commentID: commentID,
                in: comment.replies,
                transform: transform
            )

            guard updatedReplies != comment.replies else {
                return comment
            }

            return FeedComment(
                id: comment.id,
                authorName: comment.authorName,
                avatarAssetName: comment.avatarAssetName,
                text: comment.text,
                publishedAt: comment.publishedAt,
                isPostAuthor: comment.isPostAuthor,
                isOwnedByCurrentUser: comment.isOwnedByCurrentUser,
                isLiked: comment.isLiked,
                likeCount: comment.likeCount,
                replies: updatedReplies,
                petName: comment.petName,
                petAvatarAssetName: comment.petAvatarAssetName
            )
        }
    }

    private static func deleteComment(
        commentID: String,
        from comments: [FeedComment]
    ) -> [FeedComment] {
        comments.compactMap { comment in
            if comment.id == commentID {
                return nil
            }

            let updatedReplies = deleteComment(
                commentID: commentID,
                from: comment.replies
            )

            guard updatedReplies != comment.replies else {
                return comment
            }

            return FeedComment(
                id: comment.id,
                authorName: comment.authorName,
                avatarAssetName: comment.avatarAssetName,
                text: comment.text,
                publishedAt: comment.publishedAt,
                isPostAuthor: comment.isPostAuthor,
                isOwnedByCurrentUser: comment.isOwnedByCurrentUser,
                isLiked: comment.isLiked,
                likeCount: comment.likeCount,
                replies: updatedReplies,
                petName: comment.petName,
                petAvatarAssetName: comment.petAvatarAssetName
            )
        }
    }
}
