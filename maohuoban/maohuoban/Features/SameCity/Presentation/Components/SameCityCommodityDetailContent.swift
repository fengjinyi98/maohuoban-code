import SwiftUI
import MaohuobanDesignSystem

// SameCityCommodityDetailContent 同城商品详情正文
// 核心职责：
// - 按设计稿 section 组织商品价格、资料、故事、要求和发布者信息
// - 在正文底部复用 Feed 详情元信息、话题和留言树组件
struct SameCityCommodityDetailContent: View {
    let detail: SameCityCommodityDetailItem
    let comments: [FeedComment]
    let topPadding: CGFloat
    let onPublisherOffsetChange: (CGFloat) -> Void
    let onCommentReply: (FeedComment) -> Void
    let onCommentToggleLike: (FeedComment) -> Void
    let onCommentLongPress: (FeedComment) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SameCityCommodityDetailLayout.sectionSpacing) {
            SameCityCommodityDetailTitleSection(
                tradeTitle: detail.tradeTitle,
                tradeSubtitle: detail.tradeSubtitle,
                title: detail.title,
                metaTags: detail.metaTags
            )

            SameCityCommodityDetailDivider()

            SameCityCommodityHealthSection(items: detail.healthItems)

            SameCityCommodityDetailDivider()

            SameCityCommodityStorySection(
                title: detail.storyTitle,
                paragraphs: detail.storyParagraphs
            )

            SameCityCommodityDetailDivider()

            SameCityCommodityRequirementSection(
                title: detail.requirementTitle,
                requirements: detail.requirements
            )

            SameCityCommodityDetailDivider()

            SameCityCommodityDetailBottomMetadataSection(
                visibleLocationName: detail.visibleLocationName,
                viewCount: detail.viewCount,
                topics: detail.topics
            )

            SameCityCommodityPublisherSection(
                publisher: detail.publisher,
                onOffsetChange: onPublisherOffsetChange
            )

            FeedDetailCommentsSection(
                title: "留言",
                comments: comments,
                onReply: onCommentReply,
                onToggleLike: onCommentToggleLike,
                onLongPress: onCommentLongPress
            )
        }
        .padding(.horizontal, SameCityCommodityDetailLayout.contentHorizontalPadding)
        .padding(.top, topPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// SameCityCommodityDetailTitleSection 商品详情标题区
// 核心职责：
// - 展示价格或领养方式、主标题和交易说明
// - 承载基础信息标签流
private struct SameCityCommodityDetailTitleSection: View {
    let tradeTitle: String
    let tradeSubtitle: String
    let title: String
    let metaTags: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s4) {
            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
                Text(tradeTitle)
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(tradeTitleColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Text(title)
                    .font(MHBTheme.Typography.title)
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                    .lineSpacing(MHBTheme.Spacing.s1)
                    .fixedSize(horizontal: false, vertical: true)

                Text(tradeSubtitle)
                    .font(MHBTheme.Typography.footnote)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    .fixedSize(horizontal: false, vertical: true)
            }

            SameCityCommodityDetailMetaTagGrid(tags: metaTags)
        }
    }

    private var tradeTitleColor: Color {
        tradeTitle.hasPrefix("¥")
            ? MHBTheme.ColorToken.danger.color
            : MHBTheme.ColorToken.success.color
    }
}

// SameCityCommodityDetailMetaTagGrid 商品详情基础标签流
// 核心职责：
// - 展示品种、月龄和性别
// - 在窄屏下保持自动换行和稳定行距
private struct SameCityCommodityDetailMetaTagGrid: View {
    let tags: [String]

    var body: some View {
        MHBFlowLayout(
            horizontalSpacing: MHBTheme.Spacing.s2,
            verticalSpacing: MHBTheme.Spacing.s2
        ) {
            ForEach(tags, id: \.self) { tag in
                MHBTagView(tag, style: .neutral, size: .medium)
                    .lineLimit(1)
            }
        }
    }
}

// SameCityCommodityHealthSection 商品健康状况区
// 核心职责：
// - 以两列平铺方式展示健康和资质项
// - 通过完成态区分已确认与待完成事项
private struct SameCityCommodityHealthSection: View {
    let items: [SameCityCommodityDetailChecklistItem]

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s4) {
            SameCityCommoditySectionHeading(title: "健康状况")

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: MHBTheme.Spacing.s3),
                    GridItem(.flexible(), spacing: MHBTheme.Spacing.s3)
                ],
                alignment: .leading,
                spacing: MHBTheme.Spacing.s4
            ) {
                ForEach(items) { item in
                    SameCityCommodityHealthItemView(item: item)
                }
            }
        }
    }
}

// SameCityCommodityHealthItemView 商品健康检查项
// 核心职责：
// - 展示单个健康或资质标签
// - 使用图标颜色表达完成状态
private struct SameCityCommodityHealthItemView: View {
    let item: SameCityCommodityDetailChecklistItem

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s3) {
            Image(systemName: item.isCompleted ? "checkmark" : "minus")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(iconForegroundColor)
                .frame(width: 28, height: 28)
                .background(iconBackgroundColor, in: .rect(cornerRadius: MHBTheme.Radius.small))

            Text(item.title)
                .font(MHBTheme.Typography.callout.weight(.semibold))
                .foregroundStyle(textColor)
                .lineLimit(2)
                .minimumScaleFactor(0.86)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var iconForegroundColor: Color {
        item.isCompleted
            ? MHBTheme.ColorToken.success.color
            : MHBTheme.ColorToken.labelTertiary.color
    }

    private var iconBackgroundColor: Color {
        item.isCompleted
            ? MHBTheme.ColorToken.success.color.opacity(0.12)
            : MHBTheme.ColorToken.separator.color
    }

    private var textColor: Color {
        item.isCompleted
            ? MHBTheme.ColorToken.labelPrimary.color
            : MHBTheme.ColorToken.labelSecondary.color
    }
}

// SameCityCommodityStorySection 商品故事说明区
// 核心职责：
// - 展示救助故事或商品说明长文
// - 保持杂志式正文行高和阅读节奏
private struct SameCityCommodityStorySection: View {
    let title: String
    let paragraphs: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s4) {
            SameCityCommoditySectionHeading(title: title)

            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s4) {
                ForEach(paragraphs, id: \.self) { paragraph in
                    Text(paragraph)
                        .font(MHBTheme.Typography.body)
                        .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                        .lineSpacing(MHBTheme.Spacing.s2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

// SameCityCommodityRequirementSection 商品沟通要求区
// 核心职责：
// - 展示领养要求或交易须知
// - 使用警示图标强调约束条款
private struct SameCityCommodityRequirementSection: View {
    let title: String
    let requirements: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s4) {
            SameCityCommoditySectionHeading(title: title)

            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
                ForEach(requirements, id: \.self) { requirement in
                    SameCityCommodityRequirementRow(text: requirement)
                }
            }
        }
    }
}

// SameCityCommodityRequirementRow 商品要求单行
// 核心职责：
// - 承载一条领养或交易要求
// - 保持正文左侧图标对齐
private struct SameCityCommodityRequirementRow: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: MHBTheme.Spacing.s2) {
            Image(systemName: "asterisk")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(MHBTheme.ColorToken.warning.color)
                .frame(width: 18, height: 18)
                .padding(.top, 2)

            Text(text)
                .font(MHBTheme.Typography.callout.weight(.medium))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// SameCityCommodityPublisherSection 商品发布者区
// 核心职责：
// - 展示救助人、繁育人或商家认证信息
// - 为沉浸式头部身份显隐提供滚动位置观测
private struct SameCityCommodityPublisherSection: View {
    let publisher: SameCityCommodityDetailPublisher
    let onOffsetChange: (CGFloat) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
            SameCityCommoditySectionHeading(title: "发布者")

            HStack(alignment: .center, spacing: MHBTheme.Spacing.s3) {
                Image(publisher.avatarAssetName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                    .overlay {
                        Circle()
                            .stroke(MHBTheme.ColorToken.cardBorder.color, lineWidth: 1)
                    }

                VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
                    HStack(alignment: .firstTextBaseline, spacing: MHBTheme.Spacing.s2) {
                        Text(publisher.name)
                            .font(MHBTheme.Typography.callout.weight(.bold))
                            .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                            .lineLimit(1)

                        MHBTagView(
                            publisher.badgeTitle,
                            systemImage: "checkmark.seal.fill",
                            style: .primary,
                            size: .small
                        )
                        .lineLimit(1)
                    }

                    Text(publisher.subtitle)
                        .font(MHBTheme.Typography.caption)
                        .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                        .lineLimit(2)
                }
                .layoutPriority(1)
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
            }
            .padding(.vertical, MHBTheme.Spacing.s2)
            .contentShape(.rect)
        }
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.frame(in: .scrollView).minY
        } action: { minY in
            onOffsetChange(minY)
        }
    }
}

// SameCityCommodityDetailBottomMetadataSection 商品底部公开信息区
// 核心职责：
// - 在内容底部展示位置、浏览量和话题标签
// - 使用 Feed 详情元信息组件保持帖子详情一致性
private struct SameCityCommodityDetailBottomMetadataSection: View {
    let visibleLocationName: String?
    let viewCount: Int
    let topics: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
            FeedDetailMetaLine(
                visibleLocationName: visibleLocationName,
                viewCount: viewCount
            )

            if !topics.isEmpty {
                FeedDetailTopics(topics: topics)
            }
        }
    }
}

// SameCityCommoditySectionHeading 商品详情 section 标题
// 核心职责：
// - 统一正文 section 标题层级
// - 保持设计稿的粗标题阅读节奏
private struct SameCityCommoditySectionHeading: View {
    let title: String

    var body: some View {
        Text(title)
            .font(MHBTheme.Typography.headline.weight(.bold))
            .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
            .accessibilityAddTraits(.isHeader)
    }
}

// SameCityCommodityDetailDivider 商品详情分割线
// 核心职责：
// - 分隔相邻内容 section
// - 使用设计系统弱分割线降低视觉负担
private struct SameCityCommodityDetailDivider: View {
    var body: some View {
        Rectangle()
            .fill(MHBTheme.ColorToken.separatorSoft.color)
            .frame(height: 1)
            .frame(maxWidth: .infinity)
    }
}
