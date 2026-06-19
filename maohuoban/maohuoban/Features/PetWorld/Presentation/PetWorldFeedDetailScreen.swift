import SwiftUI
import MaohuobanDesignSystem

// PetWorldFeedDetailScreen 宠物世界 Feed 详情页
// 核心职责：
// - 根据帖子 ID 承载 Feed 详情系统导航目标
// - 组合主图、正文、互动状态和评论树
struct PetWorldFeedDetailScreen: View {
    let postID: String
    let interactionStore: PetWorldFeedInteractionStore

    var body: some View {
        if let detail = PetWorldMockFeedDetail.detail(for: postID) {
            PetWorldFeedDetailLoadedScreen(
                detail: detail,
                interactionStore: interactionStore
            )
        } else {
            PetWorldFeedDetailMissingScreen()
        }
    }
}

// PetWorldFeedDetailLoadedScreen 宠物世界详情已加载页面
// 核心职责：
// - 渲染帖子详情完整滚动内容
// - 保持详情页点赞状态与 Feed 列表共享同一 Store
private struct PetWorldFeedDetailLoadedScreen: View {
    @Environment(\.dismiss) private var dismiss

    let detail: PetWorldFeedDetailItem
    let interactionStore: PetWorldFeedInteractionStore

    var body: some View {
        GeometryReader { geometry in
            let interactionState = interactionStore.interactionState(
                postID: detail.postID,
                fallbackIsLiked: detail.isLiked,
                fallbackLikeCount: detail.likeCount
            )

            ZStack(alignment: .topLeading) {
                MHBTheme.ColorToken.background.color
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        PetWorldFeedDetailHeroCarousel(mediaItems: detail.mediaItems)

                        PetWorldFeedDetailContent(
                            detail: detail
                        )
                        .padding(
                            .bottom,
                            PetWorldFeedDetailLayout.inputBarReservedHeight(
                                bottomSafeArea: geometry.safeAreaInsets.bottom
                            )
                        )
                    }
                }
                .scrollIndicators(.hidden)
                .ignoresSafeArea(edges: .top)
                .zIndex(0)

                PetWorldFeedDetailHeaderControls(
                    showsDeleteAction: detail.isOwnedByCurrentUser,
                    onBack: {
                        dismiss()
                    },
                    onShare: handleShare,
                    onReport: handleReport,
                    onDelete: handleDelete
                )
                .padding(.top, MHBTheme.Spacing.s1)
                .padding(.horizontal, MHBTheme.Spacing.s4)
                .zIndex(1)

                PetWorldFeedDetailInputBar(
                    isLiked: interactionState.isLiked,
                    likeCount: interactionState.likeCount,
                    commentCount: detail.commentCount,
                    repostCount: detail.repostCount,
                    bottomSafeArea: geometry.safeAreaInsets.bottom
                ) {
                    interactionStore.toggleLike(postID: detail.postID)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .ignoresSafeArea(edges: .bottom)
                .zIndex(2)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .background(MHBInteractivePopGestureRestorer())
    }

    private func handleShare() {
        // 快速 UI 阶段暂不接入系统分享面板。
    }

    private func handleReport() {
        // 快速 UI 阶段暂不接入举报提交流程。
    }

    private func handleDelete() {
        // 快速 UI 阶段暂不接入删除提交流程。
    }
}

// PetWorldFeedDetailMissingScreen 宠物世界详情缺失页面
// 核心职责：
// - 展示无法找到帖子详情时的轻量占位
// - 保持系统导航返回能力可用
private struct PetWorldFeedDetailMissingScreen: View {
    var body: some View {
        Text("这条动态暂时不可查看")
            .font(MHBTheme.Typography.body)
            .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(MHBTheme.ColorToken.background.color)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
    }
}
