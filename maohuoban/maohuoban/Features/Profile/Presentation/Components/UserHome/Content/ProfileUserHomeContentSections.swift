import SwiftUI
import MaohuobanDesignSystem

// ProfileUserHomeTabsBar 用户主页内容 Tabs
// 核心职责：
// - 展示动态、收藏夹和赞过分栏
// - 通过绑定同步当前选中内容
struct ProfileUserHomeTabsBar: View {
    let tabs: [ProfileUserHomeTabContent]
    @Binding var selectedTabID: String

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs) { tab in
                Button {
                    selectedTabID = tab.id
                } label: {
                    VStack(spacing: 0) {
                        Text(tab.displayTitle)
                            .font(MHBTheme.Typography.callout.weight(.bold))
                            .foregroundStyle(
                                selectedTabID == tab.id
                                    ? MHBTheme.ColorToken.labelPrimary.color
                                    : MHBTheme.ColorToken.labelSecondary.color
                            )
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                            .frame(height: 50)

                        Capsule()
                            .fill(
                                selectedTabID == tab.id
                                    ? MHBTheme.ColorToken.labelPrimary.color
                                    : Color.clear
                            )
                            .frame(width: 24, height: 3)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selectedTabID == tab.id ? .isSelected : [])
            }
        }
        .padding(.horizontal, MHBTheme.Spacing.s3)
        .background {
            ZStack {
                MHBVariableBlurView(
                    maxBlurRadius: 18,
                    direction: .blurredAll,
                    startOffset: 0
                )

                MHBTheme.ColorToken.background.color.opacity(0.94)
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(MHBTheme.ColorToken.separatorSoft.color)
                .frame(height: 1)
        }
    }
}

// ProfileUserHomePostGrid 用户主页动态宫格
// 核心职责：
// - 以三列正方形宫格展示当前 tab 内容
// - 保持图片类型标记和布局尺寸稳定
struct ProfileUserHomePostGrid: View {
    let posts: [ProfileUserHomePost]
    let onOpenPost: (ProfileUserHomePost) -> Void

    var body: some View {
        LazyVGrid(columns: columns, spacing: 2) {
            ForEach(posts) { post in
                ProfileUserHomePostGridItem(
                    post: post,
                    onOpen: {
                        onOpenPost(post)
                    }
                )
            }
        }
        .padding(.top, 2)
        .padding(.bottom, MHBTheme.Spacing.s8)
    }

    private var columns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 2),
            GridItem(.flexible(), spacing: 2),
            GridItem(.flexible(), spacing: 2)
        ]
    }
}

private struct ProfileUserHomePostGridItem: View {
    let post: ProfileUserHomePost
    let onOpen: () -> Void

    var body: some View {
        if post.canOpenDetail {
            Button(action: onOpen) {
                ProfileUserHomePostGridThumbnail(post: post)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("查看动态详情")
        } else {
            ProfileUserHomePostGridThumbnail(post: post)
                .accessibilityHidden(true)
        }
    }
}

// ProfileUserHomePostGridThumbnail 用户主页宫格缩略图
// 核心职责：
// - 渲染动态封面和右上角内容类型标记
// - 为可点击和不可点击宫格项复用同一套视觉
private struct ProfileUserHomePostGridThumbnail: View {
    let post: ProfileUserHomePost

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.clear
                .aspectRatio(1, contentMode: .fill)
                .overlay(
                    Image(post.assetName)
                        .resizable()
                        .scaledToFill()
                )
                .clipped()

            if let systemImage = post.type.systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.55), radius: 4, x: 0, y: 1)
                    .padding(7)
            }
        }
        .background(MHBTheme.ColorToken.separatorSoft.color)
        .contentShape(Rectangle())
    }
}
