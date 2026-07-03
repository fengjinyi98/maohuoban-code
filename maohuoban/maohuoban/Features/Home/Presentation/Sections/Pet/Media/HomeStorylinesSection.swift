import SwiftUI
import MaohuobanDesignSystem

// HomeStorylinesSection 宠物故事线模块
// 核心职责：
// - 展示后端聚合的宠物故事线入口
// - 保持故事线与首页照护记录时间线的视觉和数据边界
struct HomeStorylinesSection: View {
    let storylines: [HomeDashboardSnapshot.StorylineSummary]
    let petName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
            HStack(spacing: MHBTheme.Spacing.s1) {
                Text("\(petName ?? "它")的故事")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
            }
            .padding(.bottom, MHBTheme.Spacing.s1)
            .accessibilityIdentifier("home.storylines.header")

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: MHBTheme.Spacing.s3) {
                    ForEach(storylines) { storyline in
                        HomeStorylineCard(storyline: storyline)
                            .accessibilityIdentifier("home.storylines.card.\(storyline.id)")
                    }
                }
                .padding(.horizontal, MHBTheme.Spacing.s4)
            }
            .padding(.horizontal, -MHBTheme.Spacing.s4)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.storylinesSection")
    }
}

// HomeStorylineCard 单个故事线卡片
// 核心职责：
// - 展示故事线封面、标题和锚点日期
// - 为后续故事详情入口保留稳定卡片形态
private struct HomeStorylineCard: View {
    let storyline: HomeDashboardSnapshot.StorylineSummary

    private var coverURL: URL? {
        guard let coverURL = storyline.coverURL else {
            return nil
        }
        return MHBBackendEndpoint.resolve(coverURL)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HomeStorylineCover(url: coverURL)

            VStack(alignment: .leading, spacing: 2) {
                Text(storyline.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .frame(maxWidth: 140, alignment: .leading)

                Text(storyline.anchorDate)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
                    .frame(maxWidth: 140, alignment: .leading)
            }
        }
        .frame(width: 140)
    }
}

// HomeStorylineCover 故事线封面
// 核心职责：
// - 优先展示宠物头像远程封面
// - 在无封面时保持卡片尺寸稳定
private struct HomeStorylineCover: View {
    let url: URL?

    var body: some View {
        MHBRemoteImage(url: url, contentMode: .fill) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(MHBTheme.ColorToken.separatorSoft.color)
                .overlay {
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.55))
                }
        }
        .frame(width: 140, height: 140)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
        }
    }
}
