import SwiftUI
import MaohuobanDesignSystem

// PetWorldFeedDetailContent 详情页正文内容
// 核心职责：
// - 组合作者信息、正文话题、推荐解释和评论树
// - 保持详情内容流与底部互动操作栏职责分离
struct PetWorldFeedDetailContent: View {
    let galleryID: String
    let detail: PetWorldFeedDetailItem
    let comments: [PetWorldFeedComment]
    let topPadding: CGFloat
    var onAuthorOffsetChange: (CGFloat) -> Void = { _ in }
    let onCommentReply: (PetWorldFeedComment) -> Void
    let onCommentToggleLike: (PetWorldFeedComment) -> Void
    let onCommentLongPress: (PetWorldFeedComment) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s6) {
            switch detail.displayMode {
            case .gallery:
                PetWorldFeedDetailGalleryArticle(
                    petName: detail.petName,
                    petAvatarAssetName: detail.petAvatarAssetName,
                    authorName: detail.authorName,
                    publishedAt: detail.publishedAt,
                    showsFollowButton: !detail.isOwnedByCurrentUser,
                    title: detail.title,
                    bodyText: detail.bodyText,
                    topics: detail.topics,
                    recommendationExplanation: detail.recommendationExplanation,
                    onAuthorOffsetChange: onAuthorOffsetChange
                )
            case .interleaved:
                PetWorldFeedDetailInterleavedArticle(
                    galleryID: galleryID,
                    petName: detail.petName,
                    petAvatarAssetName: detail.petAvatarAssetName,
                    authorName: detail.authorName,
                    publishedAt: detail.publishedAt,
                    showsFollowButton: !detail.isOwnedByCurrentUser,
                    title: detail.title,
                    contentBlocks: detail.contentBlocks,
                    topics: detail.topics,
                    recommendationExplanation: detail.recommendationExplanation,
                    onAuthorOffsetChange: onAuthorOffsetChange
                )
            }

            PetWorldFeedDetailCommentsSection(
                comments: comments,
                onReply: onCommentReply,
                onToggleLike: onCommentToggleLike,
                onLongPress: onCommentLongPress
            )
        }
        .padding(.horizontal, MHBTheme.Spacing.s5)
        .padding(.top, topPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// PetWorldFeedDetailGalleryArticle 画廊详情正文
// 核心职责：
// - 保持当前画廊详情页作者、标题、正文、话题和推荐解释布局
// - 继续作为导航作者显隐逻辑的观测入口
private struct PetWorldFeedDetailGalleryArticle: View {
    let petName: String
    let petAvatarAssetName: String
    let authorName: String
    let publishedAt: Date
    let showsFollowButton: Bool
    let title: String
    let bodyText: String
    let topics: [String]
    let recommendationExplanation: String
    let onAuthorOffsetChange: (CGFloat) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s6) {
            PetWorldFeedDetailAuthorSection(
                petName: petName,
                petAvatarAssetName: petAvatarAssetName,
                authorName: authorName,
                publishedAt: publishedAt,
                showsFollowButton: showsFollowButton,
                onOffsetChange: onAuthorOffsetChange
            )

            PetWorldFeedDetailCaption(
                title: title,
                bodyText: bodyText,
                topics: topics,
                recommendationExplanation: recommendationExplanation
            )
        }
    }
}

// PetWorldFeedDetailAuthorSection 详情页作者信息区
// 核心职责：
// - 展示宠物头像、宠物名称、作者和发布时间
// - 根据帖子所有权控制关注入口展示
struct PetWorldFeedDetailAuthorSection: View {
    let petName: String
    let petAvatarAssetName: String
    let authorName: String
    let publishedAt: Date
    let showsFollowButton: Bool
    let onOffsetChange: (CGFloat) -> Void

    var body: some View {
        HStack(alignment: .center, spacing: MHBTheme.Spacing.s3) {
            Image(petAvatarAssetName)
                .resizable()
                .scaledToFill()
                .frame(
                    width: PetWorldFeedDetailLayout.authorAvatarSize,
                    height: PetWorldFeedDetailLayout.authorAvatarSize
                )
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .stroke(MHBTheme.ColorToken.cardBorder.color, lineWidth: 1)
                }

            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
                Text(petName)
                    .font(MHBTheme.Typography.headline)
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                    .lineLimit(1)

                Text("by \(authorName) · \(publishedAt, format: MHBUTCDateDisplayFormatter.localShortDateTimeStyle())")
                    .font(MHBTheme.Typography.footnote)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    .lineLimit(1)
            }
            .layoutPriority(1)
            .frame(maxWidth: .infinity, alignment: .leading)

            if showsFollowButton {
                Button {
                    // 快速 UI 阶段暂不接入关注状态。
                } label: {
                    Text("关注")
                        .font(MHBTheme.Typography.footnote.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, MHBTheme.Spacing.s4)
                        .frame(height: MHBTheme.Spacing.s8 + MHBTheme.Spacing.s1)
                        .background(MHBTheme.ColorToken.primary.color, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("关注作者")
            }
        }
        .frame(maxWidth: .infinity)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.frame(in: .scrollView).minY
        } action: { minY in
            onOffsetChange(minY)
        }
    }
}

// PetWorldFeedDetailCaption 详情页正文区
// 核心职责：
// - 按标题、正文、话题、推荐解释顺序展示文本内容
// - 让推荐解释使用与 Feed 卡片一致的轻量信息样式
private struct PetWorldFeedDetailCaption: View {
    let title: String
    let bodyText: String
    let topics: [String]
    let recommendationExplanation: String

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s4) {
            Text(displayTitle)
                .font(MHBTheme.Typography.headline)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .fixedSize(horizontal: false, vertical: true)

            if shouldShowBodyText {
                Text(bodyText)
                    .font(MHBTheme.Typography.body)
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                    .lineSpacing(MHBTheme.Spacing.s1 + 1)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !topics.isEmpty {
                PetWorldFeedDetailTopics(topics: topics)
            }

            PetWorldFeedDetailRecommendationExplanation(text: recommendationExplanation)
        }
    }

    private var displayTitle: String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedTitle.isEmpty ? bodyText : trimmedTitle
    }

    private var shouldShowBodyText: Bool {
        let trimmedBody = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedBody.isEmpty && trimmedBody != displayTitle
    }
}

// PetWorldFeedDetailTopics 详情页话题区
// 核心职责：
// - 展示帖子正文下方的话题标签
// - 保持话题可横向浏览并避免挤压正文
struct PetWorldFeedDetailTopics: View {
    let topics: [String]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: MHBTheme.Spacing.s2) {
                ForEach(topics, id: \.self) { topic in
                    PetWorldFeedDetailTopicChip(topic: topic)
                }
            }
        }
        .scrollIndicators(.hidden)
    }
}

// PetWorldFeedDetailTopicChip 详情页话题标签
// 核心职责：
// - 呈现单个话题文本
// - 复用主题色形成轻量可点击感
private struct PetWorldFeedDetailTopicChip: View {
    let topic: String

    var body: some View {
        MHBTagView(displayText, style: .primary, size: .medium)
    }

    private var displayText: String {
        "#\(topic)"
    }
}

// PetWorldFeedDetailRecommendationExplanation 详情页推荐解释
// 核心职责：
// - 展示推荐关系的详情页解释文本
// - 复用 Feed 卡片推荐原因的信息密度和颜色层级
struct PetWorldFeedDetailRecommendationExplanation: View {
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: MHBTheme.Spacing.s1) {
            Image(systemName: "exclamationmark.circle.fill")
                .imageScale(.small)

            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(MHBTheme.Typography.footnote)
        .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
    }
}
