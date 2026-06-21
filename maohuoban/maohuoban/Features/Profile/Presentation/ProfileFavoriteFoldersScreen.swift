import SwiftUI
import MaohuobanDesignSystem

// ProfileFavoriteFoldersScreen 我的收藏夹列表页
// 核心职责：
// - 展示用户收藏夹的两列网格
// - 通过系统导航进入单个收藏夹内容页
struct ProfileFavoriteFoldersScreen<DetailRoute: Hashable>: View {
    let folders: [ProfileFavoriteFolder]
    let createRoute: DetailRoute
    let detailRoute: (ProfileFavoriteFolder) -> DetailRoute

    private let columns = [
        GridItem(.flexible(), spacing: MHBTheme.Spacing.s4),
        GridItem(.flexible(), spacing: MHBTheme.Spacing.s4)
    ]

    init(
        folders: [ProfileFavoriteFolder] = .profileFavoriteMockFolders,
        createRoute: DetailRoute,
        detailRoute: @escaping (ProfileFavoriteFolder) -> DetailRoute
    ) {
        self.folders = folders
        self.createRoute = createRoute
        self.detailRoute = detailRoute
    }

    var body: some View {
        MHBScreenScrollView {
            LazyVGrid(columns: columns, alignment: .center, spacing: MHBTheme.Spacing.s6) {
                NavigationLink(value: createRoute) {
                    ProfileFavoriteFolderCreateCard()
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("profile.favorites.create")

                ForEach(folders) { folder in
                    NavigationLink(value: detailRoute(folder)) {
                        ProfileFavoriteFolderCard(folder: folder)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("profile.favorites.folder.\(folder.id)")
                }
            }
            .padding(.horizontal, MHBTheme.Spacing.s3)
            .padding(.top, MHBTheme.Spacing.s6)
            .padding(.bottom, MHBTheme.Spacing.s8)
        }
        .background(MHBTheme.ColorToken.cardSolid.color.ignoresSafeArea())
        .navigationTitle("我的收藏夹")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: {}) {
                    Text("管理")
                        .font(MHBTheme.Typography.callout.weight(.semibold))
                }
                .accessibilityLabel("管理收藏夹")
                .accessibilityIdentifier("profile.favorites.manage")
            }
        }
        .accessibilityIdentifier("profile.favorites.screen")
    }
}

// ProfileFavoriteFolderCard 我的收藏夹卡片
// 核心职责：
// - 展示层叠封面、收藏夹名称和内容数量
// - 标记私密收藏夹状态
private struct ProfileFavoriteFolderCard: View {
    let folder: ProfileFavoriteFolder

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
            ProfileFavoriteFolderStackCover(
                imageAssetName: folder.coverImageAssetName,
                isPrivate: folder.isPrivate
            )

            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
                Text(folder.title)
                    .font(MHBTheme.Typography.body.weight(.bold))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                    .lineLimit(1)

                Text(folder.itemCountText)
                    .font(MHBTheme.Typography.caption)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    .lineLimit(1)
            }
            .padding(.horizontal, MHBTheme.Spacing.s1)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(folder.title)，\(folder.itemCountText)")
    }
}

// ProfileFavoriteFolderStackCover 收藏夹层叠封面
// 核心职责：
// - 绘制设计稿中的多层收藏夹封面
// - 在封面右上角呈现私密状态
private struct ProfileFavoriteFolderStackCover: View {
    let imageAssetName: String
    let isPrivate: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ZStack(alignment: .top) {
                // 底部第三层卡片
                RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous)
                    .fill(MHBTheme.ColorToken.labelQuaternary.color.opacity(0.6))
                    .overlay {
                        RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous)
                            .strokeBorder(MHBTheme.ColorToken.separator.color, lineWidth: 1)
                    }
                    .frame(height: MHBTheme.Spacing.s5)
                    .padding(.horizontal, MHBTheme.Spacing.s5)
                    .offset(y: -MHBTheme.Spacing.s3)

                // 底部第二层卡片
                RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous)
                    .fill(MHBTheme.ColorToken.labelQuaternary.color)
                    .overlay {
                        RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous)
                            .strokeBorder(MHBTheme.ColorToken.separator.color, lineWidth: 1)
                    }
                    .frame(height: MHBTheme.Spacing.s5)
                    .padding(.horizontal, MHBTheme.Spacing.s3)
                    .offset(y: -MHBTheme.Spacing.s3 / 2)

                // 主封面图片
                Image(imageAssetName)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.extraLarge, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: MHBTheme.Radius.extraLarge, style: .continuous)
                            .strokeBorder(MHBTheme.ColorToken.cardSolid.color.opacity(0.22), lineWidth: 3)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: MHBTheme.Radius.extraLarge, style: .continuous)
                            .strokeBorder(MHBTheme.ColorToken.separator.color, lineWidth: 1)
                    }
            }

            if isPrivate {
                Image(systemName: "lock.fill")
                    .font(.system(size: MHBTheme.IconSize.small, weight: .semibold))
                    .foregroundStyle(MHBTheme.ColorToken.cardSolid.color)
                    .frame(width: MHBTheme.Spacing.s6, height: MHBTheme.Spacing.s6)
                    .background(MHBTheme.ColorToken.labelPrimary.color.opacity(0.42), in: Circle())
                    .padding(MHBTheme.Spacing.s3)
                    .accessibilityHidden(true)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .padding(.top, MHBTheme.Spacing.s3)
        .shadow(color: MHBTheme.ColorToken.labelPrimary.color.opacity(0.06), radius: 10, y: 6)
    }
}

// ProfileFavoriteFolderCreateCard 新建收藏夹入口
// 核心职责：
// - 在收藏夹网格中提供新建入口
// - 保持与收藏夹封面一致的占位尺寸
private struct ProfileFavoriteFolderCreateCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
            VStack(spacing: MHBTheme.Spacing.s2) {
                Image(systemName: "plus")
                    .font(.system(size: MHBTheme.IconSize.medium, weight: .semibold))

                Text("新建收藏夹")
                    .font(MHBTheme.Typography.footnote.weight(.semibold))
            }
            .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .background(MHBTheme.ColorToken.background.color)
            .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.extraLarge, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: MHBTheme.Radius.extraLarge, style: .continuous)
                    .stroke(
                        MHBTheme.ColorToken.labelQuaternary.color,
                        style: StrokeStyle(lineWidth: 2, dash: [6, 6])
                    )
            }
            .padding(.top, MHBTheme.Spacing.s3) // 与其他卡片顶部的层叠间距对齐

            Text("新建收藏夹")
                .font(MHBTheme.Typography.body.weight(.bold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .padding(.horizontal, MHBTheme.Spacing.s1)
        }
        .contentShape(Rectangle())
        .accessibilityLabel("新建收藏夹")
    }
}
