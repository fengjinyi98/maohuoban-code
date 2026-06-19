import SwiftUI
import MaohuobanDesignSystem

// PetWorldFeedDetailCommentsSection 详情页评论区
// 核心职责：
// - 展示评论总数和评论树列表
// - 支持父评论与多层子评论的层级布局
struct PetWorldFeedDetailCommentsSection: View {
    let comments: [PetWorldFeedComment]

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s5) {
            HStack(alignment: .firstTextBaseline) {
                Text("评论 \(Self.totalCount(in: comments))")
                    .font(MHBTheme.Typography.headline)
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

                Spacer(minLength: 0)

                Text("按时间")
                    .font(MHBTheme.Typography.caption)
                    .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
            }

            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s5) {
                ForEach(comments) { comment in
                    PetWorldFeedDetailCommentNode(comment: comment)
                }
            }
        }
    }

    private static func totalCount(in comments: [PetWorldFeedComment]) -> Int {
        comments.reduce(0) { partialResult, comment in
            partialResult + 1 + totalCount(in: comment.replies)
        }
    }
}

// PetWorldFeedDetailCommentNode 详情页评论树节点
// 核心职责：
// - 渲染单条评论内容、时间和轻互动信息
// - 递归展示当前评论的子评论
private struct PetWorldFeedDetailCommentNode: View {
    let comment: PetWorldFeedComment

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
            PetWorldFeedDetailCommentRow(comment: comment)

            if !comment.replies.isEmpty {
                HStack(alignment: .top, spacing: MHBTheme.Spacing.s3) {
                    Rectangle()
                        .fill(MHBTheme.ColorToken.separator.color)
                        .frame(width: 1)
                        .padding(.leading, PetWorldFeedDetailLayout.commentAvatarSize / 2)
                        .padding(.vertical, MHBTheme.Spacing.s1)

                    VStack(alignment: .leading, spacing: MHBTheme.Spacing.s4) {
                        ForEach(comment.replies) { reply in
                            PetWorldFeedDetailCommentNode(comment: reply)
                        }
                    }
                }
                .padding(.leading, PetWorldFeedDetailLayout.commentAvatarSize / 2)
            }
        }
    }
}

// PetWorldFeedDetailCommentRow 详情页单条评论行
// 核心职责：
// - 展示评论作者头像、正文和发布时间
// - 提供回复和轻量点赞信息的视觉入口
private struct PetWorldFeedDetailCommentRow: View {
    let comment: PetWorldFeedComment

    var body: some View {
        HStack(alignment: .top, spacing: MHBTheme.Spacing.s3) {
            Image(comment.avatarAssetName)
                .resizable()
                .scaledToFill()
                .frame(
                    width: PetWorldFeedDetailLayout.commentAvatarSize,
                    height: PetWorldFeedDetailLayout.commentAvatarSize
                )
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
                PetWorldFeedDetailCommentAuthorLine(
                    authorName: comment.authorName,
                    isPostAuthor: comment.isPostAuthor
                )

                Text(comment.text)
                    .font(MHBTheme.Typography.callout)
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: MHBTheme.Spacing.s3) {
                    Text(comment.publishedAt, format: MHBUTCDateDisplayFormatter.localShortDateTimeStyle())
                        .font(MHBTheme.Typography.caption)
                        .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)

                    Button {
                        // 快速 UI 阶段暂不接入评论回复。
                    } label: {
                        Text("回复")
                            .font(MHBTheme.Typography.caption.weight(.medium))
                            .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    }
                    .buttonStyle(.plain)

                    Spacer(minLength: 0)

                    HStack(spacing: MHBTheme.Spacing.s1) {
                        Image(systemName: "heart")
                            .imageScale(.small)
                        Text(PetWorldCompactCountFormatter.string(for: comment.likeCount))
                    }
                    .font(MHBTheme.Typography.caption)
                    .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
                }
            }
            .layoutPriority(1)
        }
    }
}

// PetWorldFeedDetailCommentAuthorLine 评论作者行
// 核心职责：
// - 展示评论作者昵称
// - 在帖子作者评论后追加作者标签
private struct PetWorldFeedDetailCommentAuthorLine: View {
    let authorName: String
    let isPostAuthor: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: MHBTheme.Spacing.s2) {
            Text(authorName)
                .font(MHBTheme.Typography.footnote.weight(.semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .lineLimit(1)

            if isPostAuthor {
                PetWorldFeedDetailCommentAuthorBadge()
            }
        }
    }
}

// PetWorldFeedDetailCommentAuthorBadge 评论作者标签
// 核心职责：
// - 标识当前评论来自帖子作者
// - 使用低高度胶囊避免打断评论阅读
private struct PetWorldFeedDetailCommentAuthorBadge: View {
    var body: some View {
        MHBTagView("作者", style: .primary, size: .small)
    }
}
