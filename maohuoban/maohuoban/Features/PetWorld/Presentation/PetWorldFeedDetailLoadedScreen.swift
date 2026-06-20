import SwiftUI
import MaohuobanDesignSystem
import UIKit

// PetWorldFeedDetailLoadedScreen 宠物世界详情已加载页面
// 核心职责：
// - 渲染帖子详情完整滚动内容
// - 保持详情页点赞状态与 Feed 列表共享同一 Store
struct PetWorldFeedDetailLoadedScreen<TopicRouteValue: Hashable>: View {
    @Environment(\.dismiss) private var dismiss

    let detail: PetWorldFeedDetailItem
    let interactionStore: FeedInteractionStore
    let topicRoute: (String) -> TopicRouteValue
    let onOpenTopicRoute: (TopicRouteValue) -> Void
    @State private var selectedMediaIndex = 0
    @State private var isNavigationAuthorVisible = false
    @State private var isNavigationAuthorSubtitleVisible = false
    @State private var isCommentComposerPresented = false
    @State private var draftComment = ""
    @State private var replyTargetCommentID: String?
    @State private var replyTargetName: String?
    @State private var selectedCommentForActions: FeedComment?

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
                        if detail.displayMode == .gallery {
                            PetWorldFeedDetailHeroCarousel(
                                galleryID: imagePreviewGalleryID,
                                mediaItems: detail.mediaItems,
                                selectedIndex: $selectedMediaIndex
                            )
                        }

                        PetWorldFeedDetailContent(
                            galleryID: imagePreviewGalleryID,
                            detail: detail,
                            comments: comments,
                            showsRecommendationExplanation: !detail.isOwnedByCurrentUser,
                            topPadding: detailContentTopPadding(
                                topSafeArea: geometry.safeAreaInsets.top
                            ),
                            topicRoute: topicRoute,
                            onOpenTopicRoute: onOpenTopicRoute,
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
                .zIndex(0)

                PetWorldFeedDetailHeaderControls(
                    petName: detail.petName,
                    petAvatarAssetName: detail.petAvatarAssetName,
                    authorName: detail.authorName,
                    isAuthorVisible: isNavigationAuthorVisible,
                    isAuthorSubtitleVisible: isNavigationAuthorSubtitleVisible,
                    isOwnedByCurrentUser: detail.isOwnedByCurrentUser,
                    onBack: {
                        dismiss()
                    },
                    onShare: handleShare,
                    onReport: handleReport
                )
                .padding(.top, MHBTheme.Spacing.s1)
                .padding(.horizontal, MHBTheme.Spacing.s4)
                .zIndex(1)

                if isCommentComposerPresented {
                    PetWorldFeedDetailCommentInputShield(
                        onDismiss: dismissCommentComposerFromShield
                    )
                    .zIndex(1.8)
                }

                MHBKeyboardAccessoryTextViewHost(
                    isPresented: $isCommentComposerPresented,
                    text: $draftComment,
                    placeholder: commentComposerPlaceholderText,
                    minTextHeight: PetWorldFeedDetailLayout.commentComposerTextMinHeight,
                    maxTextHeight: commentComposerTextMaxHeight,
                    onDismiss: handleCommentComposerDismiss
                ) {
                    PetWorldFeedDetailCommentEditorHeader(
                        currentUserAvatarAssetName: currentUserAvatarAssetName,
                        titleText: commentComposerTitleText,
                        onDismiss: dismissCommentComposerFromShield
                    )
                } toolbar: {
                    PetWorldFeedDetailCommentComposerToolbar(
                        draftText: draftComment,
                        onSend: handleCommentSend
                    )
                }
                .frame(width: 1, height: 1)
                .allowsHitTesting(false)
                .zIndex(2)

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
            .overlay(alignment: .bottom) {
                PetWorldFeedDetailPreviewAwareBottomBar {
                    PetWorldFeedDetailInputBar(
                        isLiked: interactionState.isLiked,
                        likeCount: interactionState.likeCount,
                        commentCount: commentCount,
                        repostCount: detail.repostCount,
                        bottomSafeArea: geometry.safeAreaInsets.bottom,
                        currentUserAvatarAssetName: currentUserAvatarAssetName,
                        onCommentTap: presentCommentComposer
                    ) {
                        interactionStore.toggleLike(postID: detail.postID)
                    }
                }
                .allowsHitTesting(!isCommentComposerPresented)
                .ignoresSafeArea(edges: .bottom)
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
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
    }

    private var currentUserAvatarAssetName: String {
        "HomeUserAvatarMock"
    }

    private var currentUserName: String {
        "小满"
    }

    private var imagePreviewGalleryID: String {
        "pet-world-detail-\(detail.postID)"
    }

    private var commentComposerTitleText: String {
        if let replyTargetName {
            return "回复 @\(replyTargetName)"
        }

        return "写评论"
    }

    private var commentComposerPlaceholderText: String {
        if let replyTargetName {
            return "回复 @\(replyTargetName)..."
        }

        return "有话想说，快来评论"
    }

    private var commentComposerTextMaxHeight: CGFloat {
        ceil(
            UIFont.preferredFont(forTextStyle: .body).lineHeight *
                PetWorldFeedDetailLayout.commentComposerTextMaxLines +
                PetWorldFeedDetailLayout.commentComposerTextVerticalPadding * 2
        )
    }

    private func detailContentTopPadding(topSafeArea: CGFloat) -> CGFloat {
        switch detail.displayMode {
        case .gallery:
            return MHBTheme.Spacing.s6
        case .interleaved:
            return topSafeArea + PetWorldFeedDetailLayout.interleavedTopContentOffset
        }
    }

    private func handleShare() {
        // 快速 UI 阶段暂不接入系统分享面板。
    }

    private func handleReport() {
        // 快速 UI 阶段暂不接入举报提交流程。
    }

    private func presentCommentComposer() {
        replyTargetCommentID = nil
        replyTargetName = nil
        isCommentComposerPresented = true
    }

    private func presentReplyComposer(for comment: FeedComment) {
        replyTargetCommentID = comment.id
        replyTargetName = comment.authorName
        isCommentComposerPresented = true
    }

    private func dismissCommentComposerFromShield() {
        isCommentComposerPresented = false
        handleCommentComposerDismiss()
    }

    private func handleCommentSend() {
        let trimmedText = draftComment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            return
        }

        let newComment = FeedComment(
            id: "local-comment-\(UUID().uuidString)",
            authorName: currentUserName,
            avatarAssetName: currentUserAvatarAssetName,
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
        isCommentComposerPresented = false
    }

    private func handleCommentComposerDismiss() {
        if draftComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            replyTargetCommentID = nil
            replyTargetName = nil
        }
    }

    private func handleCommentLike(_ comment: FeedComment) {
        interactionStore.toggleCommentLike(
            postID: detail.postID,
            commentID: comment.id
        )
    }

    private func presentCommentActionSheet(for comment: FeedComment) {
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
