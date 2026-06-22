import SwiftUI
import MaohuobanDesignSystem

// FeedDetailCommentsSection Feed 详情留言区
// 核心职责：
// - 展示可配置标题的评论或留言树
// - 支持父节点与子节点的层级布局
struct FeedDetailCommentsSection: View {
    let title: String
    let comments: [FeedComment]
    var onReply: ((FeedComment) -> Void)?
    let onToggleLike: (FeedComment) -> Void
    var onLongPress: ((FeedComment) -> Void)?

    init(
        title: String,
        comments: [FeedComment],
        onReply: ((FeedComment) -> Void)? = nil,
        onToggleLike: @escaping (FeedComment) -> Void,
        onLongPress: ((FeedComment) -> Void)? = nil
    ) {
        self.title = title
        self.comments = comments
        self.onReply = onReply
        self.onToggleLike = onToggleLike
        self.onLongPress = onLongPress
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s5) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(title) \(Self.totalCount(in: comments))")
                    .font(MHBTheme.Typography.headline)
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

                Spacer(minLength: 0)

                Text("按时间")
                    .font(MHBTheme.Typography.caption)
                    .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
            }

            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s5) {
                ForEach(comments) { comment in
                    FeedDetailCommentNode(
                        comment: comment,
                        onReply: onReply,
                        onToggleLike: onToggleLike,
                        onLongPress: onLongPress
                    )
                }
            }
        }
    }

    private static func totalCount(in comments: [FeedComment]) -> Int {
        comments.reduce(0) { partialResult, comment in
            partialResult + 1 + totalCount(in: comment.replies)
        }
    }
}

// FeedDetailCommentNode Feed 详情留言树节点
// 核心职责：
// - 渲染单条留言内容、时间和轻互动信息
// - 递归展示当前留言的子留言
private struct FeedDetailCommentNode: View {
    let comment: FeedComment
    let onReply: ((FeedComment) -> Void)?
    let onToggleLike: (FeedComment) -> Void
    let onLongPress: ((FeedComment) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
            FeedDetailCommentRow(
                comment: comment,
                onReply: onReply,
                onToggleLike: onToggleLike,
                onLongPress: onLongPress
            )

            if !comment.replies.isEmpty {
                HStack(alignment: .top, spacing: MHBTheme.Spacing.s3) {
                    Rectangle()
                        .fill(MHBTheme.ColorToken.separator.color)
                        .frame(width: 1)
                        .padding(.leading, FeedDetailLayout.commentAvatarSize / 2)
                        .padding(.vertical, MHBTheme.Spacing.s1)

                    VStack(alignment: .leading, spacing: MHBTheme.Spacing.s4) {
                        ForEach(comment.replies) { reply in
                            FeedDetailCommentNode(
                                comment: reply,
                                onReply: onReply,
                                onToggleLike: onToggleLike,
                                onLongPress: onLongPress
                            )
                        }
                    }
                }
                .padding(.leading, FeedDetailLayout.commentAvatarSize / 2)
            }
        }
    }
}

// FeedDetailCommentRow Feed 详情单条留言行
// 核心职责：
// - 展示留言作者头像、正文和发布时间
// - 提供回复和轻量点赞信息的视觉入口
private struct FeedDetailCommentRow: View {
    let comment: FeedComment
    let onReply: ((FeedComment) -> Void)?
    let onToggleLike: (FeedComment) -> Void
    let onLongPress: ((FeedComment) -> Void)?

    @State private var isPressing = false
    @State private var hapticTrigger = 0
    @State private var isLikeFeedbackActive = false

    var body: some View {
        HStack(alignment: .top, spacing: MHBTheme.Spacing.s1) {
            Image(comment.avatarAssetName)
                .resizable()
                .scaledToFill()
                .frame(
                    width: FeedDetailLayout.commentAvatarSize,
                    height: FeedDetailLayout.commentAvatarSize
                )
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
                FeedDetailCommentAuthorLine(
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

                    if let onReply {
                        Button {
                            onReply(comment)
                        } label: {
                            Text("回复")
                                .font(MHBTheme.Typography.caption.weight(.medium))
                                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer(minLength: 0)

                    Button {
                        triggerLikeFeedback()
                        onToggleLike(comment)
                    } label: {
                        HStack(spacing: MHBTheme.Spacing.s1) {
                            Image(systemName: comment.isLiked ? "heart.fill" : "heart")
                                .imageScale(.small)
                                .scaleEffect(isLikeFeedbackActive ? FeedDetailLayout.likeFeedbackScale : 1)

                            Text(comment.likeCount > 0 ? FeedCompactCountFormatter.string(for: comment.likeCount) : "赞")
                        }
                        .font(MHBTheme.Typography.caption)
                        .foregroundStyle(comment.isLiked ? MHBTheme.ColorToken.danger.color : MHBTheme.ColorToken.labelTertiary.color)
                    }
                    .buttonStyle(.plain)
                    .sensoryFeedback(.selection, trigger: isLikeFeedbackActive)
                    .accessibilityLabel(comment.isLiked ? "取消点赞" : "点赞")
                }
            }
            .padding(.vertical, MHBTheme.Spacing.s1)
            .padding(.horizontal, MHBTheme.Spacing.s2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
            .background(
                RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous)
                    .fill(MHBTheme.ColorToken.primary.color.opacity(isPressing ? 0.08 : 0))
            )
            .scaleEffect(isPressing ? 0.985 : 1)
            .animation(.easeOut(duration: 0.16), value: isPressing)
            .sensoryFeedback(.selection, trigger: hapticTrigger)
            .modifier(
                FeedDetailCommentLongPressModifier(
                    comment: comment,
                    onLongPress: onLongPress,
                    onPressingChange: updatePressingState(_:),
                    onTrigger: {
                        hapticTrigger += 1
                    }
                )
            )
            .layoutPriority(1)
        }
    }

    private func updatePressingState(_ isPressing: Bool) {
        self.isPressing = isPressing
    }

    private func triggerLikeFeedback() {
        withAnimation(FeedDetailLayout.likePressAnimation) {
            isLikeFeedbackActive = true
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(120))
            withAnimation(FeedDetailLayout.likeReleaseAnimation) {
                isLikeFeedbackActive = false
            }
        }
    }
}

// FeedDetailCommentLongPressModifier 留言长按动作修饰器
// 核心职责：
// - 仅在调用方提供长按动作时安装手势
// - 避免静态留言区出现无效按压反馈
private struct FeedDetailCommentLongPressModifier: ViewModifier {
    let comment: FeedComment
    let onLongPress: ((FeedComment) -> Void)?
    let onPressingChange: (Bool) -> Void
    let onTrigger: () -> Void

    func body(content: Content) -> some View {
        if let onLongPress {
            content
                .onLongPressGesture(minimumDuration: 0.35, pressing: onPressingChange) {
                    onTrigger()
                    onLongPress(comment)
                }
        } else {
            content
        }
    }
}

// FeedDetailCommentAuthorLine Feed 详情留言作者行
// 核心职责：
// - 展示留言作者昵称
// - 在发布者留言后追加作者标签
private struct FeedDetailCommentAuthorLine: View {
    let authorName: String
    let isPostAuthor: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: MHBTheme.Spacing.s2) {
            Text(authorName)
                .font(MHBTheme.Typography.footnote.weight(.semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .lineLimit(1)

            if isPostAuthor {
                FeedDetailCommentAuthorBadge()
            }
        }
    }
}

// FeedDetailCommentAuthorBadge Feed 详情发布者标签
// 核心职责：
// - 标识当前留言来自发布者
// - 使用低高度胶囊避免打断阅读
private struct FeedDetailCommentAuthorBadge: View {
    var body: some View {
        Text("作者")
            .font(MHBTheme.Typography.section)
            .foregroundStyle(MHBTheme.ColorToken.primary.color)
            .padding(.horizontal, MHBTheme.Spacing.s2)
            .padding(.vertical, 2)
            .background(MHBTheme.ColorToken.primaryBackgroundSoft.color, in: Capsule())
    }
}
