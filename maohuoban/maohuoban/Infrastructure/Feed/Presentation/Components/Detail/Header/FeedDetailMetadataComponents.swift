import SwiftUI
import MaohuobanDesignSystem

// FeedDetailMetaLine Feed 详情公开元信息行
// 核心职责：
// - 按发布选择展示位置
// - 在同一行展示浏览量
struct FeedDetailMetaLine: View {
    let visibleLocationName: String?
    let viewCount: Int

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: MHBTheme.Spacing.s2) {
            if let displayLocationName {
                FeedDetailMetaItem(
                    icon: .asset("IconLocationPin"),
                    text: displayLocationName
                )
            }

            FeedDetailMetaItem(
                icon: .system("eye.fill"),
                text: "\(FeedCompactCountFormatter.string(for: viewCount)) 浏览"
            )
        }
        .font(MHBTheme.Typography.footnote)
        .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
    }

    private var displayLocationName: String? {
        let trimmedLocationName = visibleLocationName?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmedLocationName,
              !trimmedLocationName.isEmpty
        else {
            return nil
        }

        return trimmedLocationName
    }
}

// FeedDetailTopics Feed 详情话题区
// 核心职责：
// - 展示详情正文下方的话题标签
// - 通过回调把话题点击交给所属 Feature
struct FeedDetailTopics: View {
    let topics: [String]
    var onTopicTap: (String) -> Void = { _ in }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: MHBTheme.Spacing.s2) {
                ForEach(topics, id: \.self) { topic in
                    FeedDetailTopicChip(
                        topic: topic,
                        onTap: {
                            onTopicTap(topic)
                        }
                    )
                }
            }
        }
        .scrollIndicators(.hidden)
    }
}

// FeedDetailTopicChip Feed 详情话题标签
// 核心职责：
// - 呈现单个话题文本
// - 保持与帖子详情页一致的标签视觉
private struct FeedDetailTopicChip: View {
    let topic: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            MHBTagView(displayText, style: .primary, size: .medium)
        }
        .buttonStyle(.plain)
        .contentShape(Capsule())
    }

    private var displayText: String {
        "#\(topic)"
    }
}

// FeedDetailMetaIcon Feed 详情元信息图标来源
// 核心职责：
// - 区分自定义资源图标与系统符号图标
// - 让元信息项复用统一文本与颜色层级
private enum FeedDetailMetaIcon {
    case asset(String)
    case system(String)
}

// FeedDetailMetaItem Feed 详情元信息项
// 核心职责：
// - 统一位置与浏览量的图标文本样式
// - 保持轻量信息层级
private struct FeedDetailMetaItem: View {
    let icon: FeedDetailMetaIcon
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: MHBTheme.Spacing.s1) {
            switch icon {
            case let .asset(assetName):
                Image(assetName)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 12, height: 12)
            case let .system(systemImageName):
                Image(systemName: systemImageName)
                    .imageScale(.small)
            }

            Text(text)
                .lineLimit(1)
        }
    }
}
