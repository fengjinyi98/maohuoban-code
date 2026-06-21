import SwiftUI
import MaohuobanDesignSystem

// ProfileFavoriteFolderContentScreen 收藏夹内容页
// 核心职责：
// - 展示单个收藏夹内的 Feed 内容
// - 复用我的动态 Feed 布局和互动状态
struct ProfileFavoriteFolderContentScreen: View {
    let folderID: String
    let interactionStore: FeedInteractionStore
    let folders: [ProfileFavoriteFolder]
    let allItems: [FeedItem]

    init(
        folderID: String,
        interactionStore: FeedInteractionStore,
        folders: [ProfileFavoriteFolder] = .profileFavoriteMockFolders,
        allItems: [FeedItem] = ProfileMockFeed.cards
    ) {
        self.folderID = folderID
        self.interactionStore = interactionStore
        self.folders = folders
        self.allItems = allItems
    }

    var body: some View {
        ZStack {
            MHBTheme.ColorToken.background.color
                .ignoresSafeArea()

            FeedList(
                cards: feedItems,
                interactionStore: interactionStore,
                topContentInset: MHBTheme.Spacing.s4,
                accessibilityIdentifierPrefix: "profile.favoriteFolder.feed.card",
                topTrailingAction: .moreMenu,
                showsRecommendationReason: false,
                detailRoute: { card in
                    ProfileRoute.feedDetail(postID: card.postID)
                }
            )
            .accessibilityIdentifier("profile.favoriteFolder.feedList")
        }
        .navigationTitle(folderTitle)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("profile.favoriteFolder.screen.\(folderID)")
    }

    private var folderTitle: String {
        ProfileFavoriteFolderContentResolver.folder(
            id: folderID,
            folders: folders
        )?.title ?? "收藏夹"
    }

    private var feedItems: [FeedItem] {
        ProfileFavoriteFolderContentResolver.feedItems(
            folderID: folderID,
            folders: folders,
            allItems: allItems
        )
    }
}
