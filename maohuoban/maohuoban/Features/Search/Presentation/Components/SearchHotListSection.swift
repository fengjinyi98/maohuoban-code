import SwiftUI
import MaohuobanDesignSystem

// SearchHotListSection 搜索热搜榜单区
// 核心职责：
// - 展示当前入口对应的热搜榜单标题
// - 承载热搜词条点击回填搜索框
struct SearchHotListSection: View {
    let title: String
    let keywords: [SearchHotKeyword]
    let onSelectKeyword: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s4) {
            Text(title)
                .font(MHBTheme.Typography.callout.weight(.bold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

            VStack(spacing: MHBTheme.Spacing.s4) {
                ForEach(keywords) { keyword in
                    SearchHotKeywordRow(
                        keyword: keyword,
                        onSelectKeyword: onSelectKeyword
                    )
                }
            }
        }
        .padding(.horizontal, MHBTheme.Spacing.s6)
        .padding(.vertical, MHBTheme.Spacing.s5)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("search.hot.section")
    }
}

// SearchHotKeywordRow 搜索热搜行
// 核心职责：
// - 展示热搜排名、关键词、角标和热度
// - 将热搜点击转发给页面搜索框
private struct SearchHotKeywordRow: View {
    let keyword: SearchHotKeyword
    let onSelectKeyword: (String) -> Void

    var body: some View {
        Button {
            onSelectKeyword(keyword.title)
        } label: {
            HStack(spacing: MHBTheme.Spacing.s3) {
                Text("\(keyword.rank)")
                    .font(.system(size: 16, weight: .black).italic())
                    .foregroundStyle(rankColor)
                    .frame(width: MHBTheme.Spacing.s5, alignment: .center)

                HStack(spacing: MHBTheme.Spacing.s2) {
                    Text(keyword.title)
                        .font(MHBTheme.Typography.callout.weight(.semibold))
                        .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                        .lineLimit(1)

                    if let badge = keyword.badge {
                        SearchHotKeywordBadgeView(badge: badge)
                    }
                }

                Spacer(minLength: MHBTheme.Spacing.s3)

                Text(keyword.scoreText)
                    .font(MHBTheme.Typography.caption.weight(.medium))
                    .foregroundStyle(MHBTheme.ColorToken.labelQuaternary.color)
                    .monospacedDigit()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("热搜第\(keyword.rank)名 \(keyword.title)")
    }

    private var rankColor: Color {
        switch keyword.rank {
        case 1:
            MHBTheme.ColorToken.danger.color
        case 2:
            MHBTheme.ColorToken.warning.color
        case 3:
            MHBTheme.ColorToken.warning.color.opacity(0.72)
        default:
            MHBTheme.ColorToken.labelQuaternary.color
        }
    }
}

// SearchHotKeywordBadgeView 搜索热搜角标
// 核心职责：
// - 根据热搜语义展示短标签文案
// - 区分热门、新内容和同城拼单状态
private struct SearchHotKeywordBadgeView: View {
    let badge: SearchHotKeywordBadge

    var body: some View {
        Text(badge.title)
            .font(.system(size: 10, weight: .black))
            .foregroundStyle(badge.foregroundColor)
            .padding(.horizontal, MHBTheme.Spacing.s1)
            .frame(height: MHBTheme.Spacing.s5)
            .background(badge.backgroundColor, in: .rect(cornerRadius: MHBTheme.Radius.small))
    }
}

private extension SearchHotKeywordBadge {
    var title: String {
        switch self {
        case .hot:
            "热"
        case .new:
            "新"
        case .cobuy:
            "拼单中"
        }
    }

    var foregroundColor: Color {
        switch self {
        case .hot:
            MHBTheme.ColorToken.danger.color
        case .new:
            MHBTheme.ColorToken.primary.color
        case .cobuy:
            MHBTheme.ColorToken.warning.color
        }
    }

    var backgroundColor: Color {
        foregroundColor.opacity(0.12)
    }
}
