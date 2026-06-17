import SwiftUI
import MaohuobanDesignSystem

// PetWorldFeedCard 宠物世界信息流卡片
// 核心职责：
// - 展示单条宠物事件内容
// - 保持宠物身份、内容主体和推荐解释的轻重层级
struct PetWorldFeedCard: View {
    let item: PetWorldFeedItem

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
            PetWorldPetIdentityHeader(
                pet: item.pet,
                authorName: item.authorName
            )

            PetWorldMediaPreview(media: item.media)

            PetWorldCardText(
                text: item.text,
                topics: item.topics
            )

            PetWorldInteractionBar(
                reactions: item.reactions,
                badge: item.badge
            )
        }
        .padding(MHBTheme.Spacing.s4)
        .background(MHBTheme.ColorToken.card.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.extraLarge, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MHBTheme.Radius.extraLarge, style: .continuous)
                .stroke(MHBTheme.ColorToken.cardBorder.color, lineWidth: 0.5)
        }
    }
}

// PetWorldPetIdentityHeader 宠物事件主身份头部
// 核心职责：
// - 让宠物成为卡片主身份
// - 将人类作者弱化为次级署名
struct PetWorldPetIdentityHeader: View {
    let pet: PetWorldPetSummary
    let authorName: String

    var body: some View {
        HStack(alignment: .center, spacing: MHBTheme.Spacing.s3) {
            Image(systemName: pet.systemImage)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.primary.color)
                .frame(width: 46, height: 46)
                .background(MHBTheme.ColorToken.primaryBackground.color)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: MHBTheme.Spacing.s2) {
                    Text(pet.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

                    Text("@\(authorName)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                }

                Text("\(pet.breed) · \(pet.ageStage)")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
            }

            Spacer(minLength: MHBTheme.Spacing.s2)

            Button {
                // TODO: 接入关注宠物动作。
            } label: {
                MHBTagView(
                    "关注",
                    style: .primary,
                    size: .medium
                )
            }
            .buttonStyle(.plain)
        }
    }
}

// PetWorldMediaPreview 宠物事件媒体占位
// 核心职责：
// - 在快速 UI 阶段呈现图片 / 视频主体区域
// - 后续替换为真实媒体渲染组件
struct PetWorldMediaPreview: View {
    let media: PetWorldMediaPresentation

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: media.tone.gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Image(systemName: media.systemImage)
                .font(.system(size: 54, weight: .semibold))
                .foregroundStyle(.white.opacity(0.86))
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
                Text(media.title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)

                Text(media.subtitle)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.white.opacity(0.78))
            }
            .padding(MHBTheme.Spacing.s4)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1.35, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
    }
}

// PetWorldCardText 宠物事件正文和话题
// 核心职责：
// - 展示事件正文摘要
// - 使用话题承接经验聚合和搜索
struct PetWorldCardText: View {
    let text: String
    let topics: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
            Text(text)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .lineSpacing(3)
                .lineLimit(3)

            HStack(spacing: MHBTheme.Spacing.s2) {
                ForEach(topics, id: \.self) { topic in
                    Text("#\(topic)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(MHBTheme.ColorToken.primary.color)
                }
            }
        }
    }
}

// PetWorldInteractionBar 宠物事件互动和推荐短标签
// 核心职责：
// - 展示点赞、评论和收藏入口
// - 以低干扰短标签展示推荐原因
struct PetWorldInteractionBar: View {
    let reactions: PetWorldReactionSummary
    let badge: PetWorldRecommendationBadge

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s4) {
            PetWorldInteractionMetric(
                systemImage: "heart",
                value: reactions.likeCount
            )

            PetWorldInteractionMetric(
                systemImage: "bubble.left",
                value: reactions.commentCount
            )

            PetWorldInteractionMetric(
                systemImage: "bookmark",
                value: reactions.saveCount
            )

            Spacer(minLength: MHBTheme.Spacing.s2)

            PetWorldRecommendationBadgeView(badge: badge)
        }
        .padding(.top, MHBTheme.Spacing.s1)
    }
}

// PetWorldInteractionMetric 宠物事件互动指标
// 核心职责：
// - 统一渲染单个互动指标
// - 保持底部操作栏尺寸稳定
struct PetWorldInteractionMetric: View {
    let systemImage: String
    let value: Int

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s1) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .medium))

            Text("\(value)")
                .font(.system(size: 13, weight: .medium))
        }
        .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
        .frame(minWidth: 42, alignment: .leading)
    }
}

// PetWorldRecommendationBadgeView 推荐解释短标签
// 核心职责：
// - 将推荐原因压缩为轻量标签
// - 避免 Feed 卡片承载过重解释文案
struct PetWorldRecommendationBadgeView: View {
    let badge: PetWorldRecommendationBadge

    var body: some View {
        MHBTagView(
            badge.title,
            style: badge.style.tagStyle,
            size: .small
        )
        .accessibilityLabel(badge.explanation)
    }
}
