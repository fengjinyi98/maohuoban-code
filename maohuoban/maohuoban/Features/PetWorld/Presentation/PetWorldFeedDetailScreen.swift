import SwiftUI
import MaohuobanDesignSystem
import UIKit

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
    @State private var selectedMediaIndex = 0
    @State private var isNavigationAuthorVisible = false
    @State private var isNavigationAuthorSubtitleVisible = false
    @State private var isCommentComposerPresented = false
    @State private var draftComment = ""
    @State private var replyTargetCommentID: String?
    @State private var replyTargetName: String?
    @State private var selectedCommentForActions: PetWorldFeedComment?
    @State private var doubleTapLikeBursts: [PetWorldFeedDetailDoubleTapLikeBurst] = []

    var body: some View {
        GeometryReader { geometry in
            let interactionState = interactionStore.interactionState(
                postID: detail.postID,
                fallbackIsLiked: detail.isLiked,
                fallbackLikeCount: detail.likeCount
            )
            let comments = interactionStore.comments(
                postID: detail.postID,
                fallbackComments: detail.comments
            )
            let commentCount = interactionStore.commentCount(
                postID: detail.postID,
                fallbackComments: detail.comments
            )

            ZStack(alignment: .topLeading) {
                MHBTheme.ColorToken.background.color
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        PetWorldFeedDetailHeroCarousel(
                            galleryID: imagePreviewGalleryID,
                            mediaItems: detail.mediaItems,
                            selectedIndex: $selectedMediaIndex
                        )

                        PetWorldFeedDetailContent(
                            detail: detail,
                            comments: comments,
                            onAuthorOffsetChange: updateNavigationAuthorOffset(_:),
                            onCommentReply: presentReplyComposer(for:),
                            onCommentToggleLike: handleCommentLike(_:),
                            onCommentLongPress: presentCommentActionSheet(for:)
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
                .highPriorityGesture(
                    SpatialTapGesture(count: 2, coordinateSpace: .local)
                        .onEnded { value in
                            handleDoubleTapLike(
                                at: value.location,
                                currentIsLiked: interactionState.isLiked
                            )
                        },
                    including: .all
                )
                .zIndex(0)

                PetWorldFeedDetailHeaderControls(
                    petName: detail.petName,
                    petAvatarAssetName: detail.petAvatarAssetName,
                    authorName: detail.authorName,
                    isAuthorVisible: isNavigationAuthorVisible,
                    isAuthorSubtitleVisible: isNavigationAuthorSubtitleVisible,
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

                PetWorldFeedDetailDoubleTapLikeOverlay(bursts: doubleTapLikeBursts)
                    .zIndex(1.5)

                PetWorldFeedDetailPreviewAwareBottomBar {
                    PetWorldFeedDetailInputBar(
                        isLiked: interactionState.isLiked,
                        likeCount: interactionState.likeCount,
                        commentCount: commentCount,
                        repostCount: detail.repostCount,
                        bottomSafeArea: geometry.safeAreaInsets.bottom,
                        currentUserAvatarAssetName: Self.currentUserAvatarAssetName,
                        onCommentTap: presentCommentComposer
                    ) {
                        interactionStore.toggleLike(postID: detail.postID)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .ignoresSafeArea(edges: .bottom)
                .zIndex(2)

                if isCommentComposerPresented {
                    PetWorldFeedDetailCommentComposerOverlay(
                        isPresented: $isCommentComposerPresented,
                        draftText: $draftComment,
                        replyTargetName: replyTargetName,
                        currentUserAvatarAssetName: Self.currentUserAvatarAssetName,
                        onSend: handleCommentSend,
                        onDismiss: handleCommentComposerDismiss
                    )
                    .zIndex(3)
                }

                if let selectedCommentForActions {
                    PetWorldFeedDetailCommentActionSheetOverlay(
                        comment: selectedCommentForActions,
                        onDismiss: dismissCommentActionSheet,
                        onReply: replyFromActionSheet,
                        onCopy: copySelectedComment,
                        onReport: reportSelectedComment,
                        onDelete: deleteSelectedComment
                    )
                    .zIndex(4)
                }
            }
        }
        .mhbImagePreviewHost()
        .task(id: detail.postID) {
            interactionStore.prepareCommentsIfNeeded(
                postID: detail.postID,
                comments: detail.comments
            )
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .background(MHBInteractivePopGestureRestorer())
    }

    private static let currentUserAvatarAssetName = "HomeUserAvatarMock"
    private static let currentUserName = "小满"

    private var imagePreviewGalleryID: String {
        "pet-world-detail-\(detail.postID)"
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

    private func presentCommentComposer() {
        replyTargetCommentID = nil
        replyTargetName = nil
        isCommentComposerPresented = true
    }

    private func presentReplyComposer(for comment: PetWorldFeedComment) {
        replyTargetCommentID = comment.id
        replyTargetName = comment.authorName
        isCommentComposerPresented = true
    }

    private func handleCommentSend() {
        let trimmedText = draftComment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            return
        }

        let newComment = PetWorldFeedComment(
            id: "local-comment-\(UUID().uuidString)",
            authorName: Self.currentUserName,
            avatarAssetName: Self.currentUserAvatarAssetName,
            text: trimmedText,
            publishedAt: Date(),
            isPostAuthor: detail.isOwnedByCurrentUser,
            isOwnedByCurrentUser: true,
            isLiked: false,
            likeCount: 0,
            replies: []
        )

        interactionStore.addComment(
            postID: detail.postID,
            parentCommentID: replyTargetCommentID,
            comment: newComment
        )

        draftComment = ""
        replyTargetCommentID = nil
        replyTargetName = nil
    }

    private func handleCommentComposerDismiss() {
        if draftComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            replyTargetCommentID = nil
            replyTargetName = nil
        }
    }

    private func handleCommentLike(_ comment: PetWorldFeedComment) {
        interactionStore.toggleCommentLike(
            postID: detail.postID,
            commentID: comment.id
        )
    }

    private func handleDoubleTapLike(
        at location: CGPoint,
        currentIsLiked: Bool
    ) {
        guard !isCommentComposerPresented,
              selectedCommentForActions == nil
        else {
            return
        }

        let nextIsLiked = !currentIsLiked
        let burst = PetWorldFeedDetailDoubleTapLikeBurst(
            location: location,
            isLiked: nextIsLiked
        )

        UIImpactFeedbackGenerator(style: .soft).impactOccurred(
            intensity: nextIsLiked ? 0.9 : 0.58
        )
        doubleTapLikeBursts.append(burst)
        interactionStore.toggleLike(postID: detail.postID)

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(760))
            doubleTapLikeBursts.removeAll { $0.id == burst.id }
        }
    }

    private func presentCommentActionSheet(for comment: PetWorldFeedComment) {
        withAnimation(PetWorldFeedDetailLayout.commentComposerAnimation) {
            selectedCommentForActions = comment
        }
    }

    private func dismissCommentActionSheet() {
        withAnimation(PetWorldFeedDetailLayout.commentComposerAnimation) {
            selectedCommentForActions = nil
        }
    }

    private func replyFromActionSheet() {
        guard let selectedCommentForActions else {
            return
        }

        dismissCommentActionSheet()
        presentReplyComposer(for: selectedCommentForActions)
    }

    private func copySelectedComment() {
        guard let selectedCommentForActions else {
            return
        }

        UIPasteboard.general.string = selectedCommentForActions.text
        dismissCommentActionSheet()
    }

    private func reportSelectedComment() {
        dismissCommentActionSheet()
    }

    private func deleteSelectedComment() {
        guard let selectedCommentForActions else {
            return
        }

        interactionStore.deleteComment(
            postID: detail.postID,
            commentID: selectedCommentForActions.id
        )
        dismissCommentActionSheet()
    }

    private func updateNavigationAuthorOffset(_ minY: CGFloat) {
        let primaryShowThreshold: CGFloat = MHBTheme.Spacing.s8
        let primaryHideThreshold: CGFloat = MHBTheme.Spacing.s8 + MHBTheme.Spacing.s5
        let subtitleShowThreshold: CGFloat = 0
        let subtitleHideThreshold: CGFloat = MHBTheme.Spacing.s5

        let nextPrimaryVisible: Bool
        if isNavigationAuthorVisible {
            nextPrimaryVisible = minY <= primaryHideThreshold
        } else {
            nextPrimaryVisible = minY <= primaryShowThreshold
        }

        let nextSubtitleVisible: Bool
        if isNavigationAuthorSubtitleVisible {
            nextSubtitleVisible = nextPrimaryVisible && minY <= subtitleHideThreshold
        } else {
            nextSubtitleVisible = nextPrimaryVisible && minY <= subtitleShowThreshold
        }

        guard nextPrimaryVisible != isNavigationAuthorVisible ||
              nextSubtitleVisible != isNavigationAuthorSubtitleVisible
        else {
            return
        }

        withAnimation(.easeInOut(duration: 0.22)) {
            isNavigationAuthorVisible = nextPrimaryVisible
            isNavigationAuthorSubtitleVisible = nextSubtitleVisible
        }
    }
}

// PetWorldFeedDetailPreviewAwareBottomBar 详情底部栏预览态保护容器
// 核心职责：
// - 在大图预览打开时隐藏业务底部操作栏
// - 避免页面内 overlay 穿透到图片预览层
private struct PetWorldFeedDetailPreviewAwareBottomBar<Content: View>: View {
    @Environment(\.mhbImagePreviewPresenting) private var isImagePreviewPresenting

    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .opacity(isImagePreviewPresenting ? 0 : 1)
            .allowsHitTesting(!isImagePreviewPresenting)
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
