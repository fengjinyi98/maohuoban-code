import SwiftUI
import MaohuobanDesignSystem
import UIKit

// SameCityCommodityDetailScreen 同城商品详情页
// 核心职责：
// - 根据商品 postID 承载系统导航目标
// - 组合沉浸式头图、详情正文、留言和底部操作栏
struct SameCityCommodityDetailScreen: View {
    let postID: String
    let interactionStore: FeedInteractionStore

    var body: some View {
        if let detail = SameCityCommodityMockDetail.detail(for: postID) {
            SameCityCommodityDetailLoadedScreen(
                detail: detail,
                interactionStore: interactionStore
            )
        } else {
            SameCityCommodityDetailMissingScreen()
        }
    }
}

// SameCityCommodityDetailLoadedScreen 同城商品详情已加载页面
// 核心职责：
// - 保持商品详情点赞与 Feed 列表共享同一 Store
// - 复用帖子详情画廊模式的沉浸式滚动和头部控件
private struct SameCityCommodityDetailLoadedScreen: View {
    @Environment(\.dismiss) private var dismiss

    let detail: SameCityCommodityDetailItem
    let interactionStore: FeedInteractionStore

    @State private var selectedMediaIndex = 0
    @State private var isNavigationIdentityVisible = false
    @State private var isNavigationSubtitleVisible = false
    @State private var isCommentComposerPresented = false
    @State private var draftComment = ""
    @State private var replyTargetCommentID: String?
    @State private var replyTargetName: String?
    @State private var selectedCommentForActions: FeedComment?
    @State private var isFavorite = false

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

            ZStack(alignment: .bottom) {
                ZStack(alignment: .topLeading) {
                    MHBTheme.ColorToken.background.color
                        .ignoresSafeArea()

                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 0) {
                            FeedDetailHeroCarousel(
                                galleryID: imagePreviewGalleryID,
                                mediaItems: detail.mediaItems,
                                selectedIndex: $selectedMediaIndex,
                                accessibilityLabel: "商品图片"
                            )

                            SameCityCommodityDetailContent(
                                detail: detail,
                                comments: comments,
                                topPadding: MHBTheme.Spacing.s6,
                                onPublisherOffsetChange: updateNavigationIdentityOffset(_:),
                                onCommentReply: presentReplyComposer(for:),
                                onCommentToggleLike: handleCommentLike(_:),
                                onCommentLongPress: presentCommentActionSheet(for:)
                            )
                            .padding(
                                .bottom,
                                SameCityCommodityDetailLayout.bottomBarReservedHeight(
                                    bottomSafeArea: geometry.safeAreaInsets.bottom
                                )
                            )
                        }
                    }
                    .scrollIndicators(.hidden)
                    .ignoresSafeArea(edges: .top)
                    .zIndex(0)

                    FeedDetailHeaderControls(
                        title: detail.title,
                        avatarAssetName: detail.publisher.avatarAssetName,
                        subtitle: detail.tradeTitle,
                        isIdentityVisible: isNavigationIdentityVisible,
                        isSubtitleVisible: isNavigationSubtitleVisible,
                        isOwnedByCurrentUser: false,
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
                        FeedDetailCommentInputShield(
                            onDismiss: dismissCommentComposerFromShield
                        )
                        .zIndex(1.8)
                    }

                    MHBKeyboardAccessoryTextViewHost(
                        isPresented: $isCommentComposerPresented,
                        text: $draftComment,
                        placeholder: commentComposerPlaceholderText,
                        minTextHeight: FeedDetailLayout.commentComposerTextMinHeight,
                        maxTextHeight: commentComposerTextMaxHeight,
                        onDismiss: handleCommentComposerDismiss
                    ) {
                        FeedDetailCommentEditorHeader(
                            currentUserAvatarAssetName: currentUserAvatarAssetName,
                            titleText: commentComposerTitleText,
                            onDismiss: dismissCommentComposerFromShield
                        )
                    } toolbar: {
                        FeedDetailCommentComposerToolbar(
                            draftText: draftComment,
                            onSend: handleCommentSend
                        )
                    }
                    .frame(width: 1, height: 1)
                    .allowsHitTesting(false)
                    .zIndex(2)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                FeedDetailPreviewAwareBottomBar {
                    SameCityCommodityDetailBottomBar(
                        isFavorite: isFavorite,
                        isLiked: interactionState.isLiked,
                        bottomSafeArea: geometry.safeAreaInsets.bottom,
                        onToggleFavorite: toggleFavorite,
                        onToggleLike: {
                            interactionStore.toggleLike(postID: detail.postID)
                        },
                        onPrivateChat: handlePrivateChat
                    )
                }
                .allowsHitTesting(!isCommentComposerPresented)
                .ignoresSafeArea(edges: .bottom)
                .zIndex(3)

                if let selectedCommentForActions {
                    FeedDetailCommentActionSheetOverlay(
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

    private var imagePreviewGalleryID: String {
        "same-city-commodity-detail-\(detail.postID)"
    }

    private var currentUserAvatarAssetName: String {
        "HomeUserAvatarMock"
    }

    private var currentUserName: String {
        "小满"
    }

    private var commentComposerTitleText: String {
        if let replyTargetName {
            return "回复 @\(replyTargetName)"
        }

        return "写留言"
    }

    private var commentComposerPlaceholderText: String {
        if let replyTargetName {
            return "回复 @\(replyTargetName)..."
        }

        return "留下你的问题或想法"
    }

    private var commentComposerTextMaxHeight: CGFloat {
        ceil(
            UIFont.preferredFont(forTextStyle: .body).lineHeight *
                FeedDetailLayout.commentComposerTextMaxLines +
                FeedDetailLayout.commentComposerTextVerticalPadding * 2
        )
    }

    private func handleShare() {
        // 快速 UI 阶段暂不接入系统分享面板。
    }

    private func handleReport() {
        // 快速 UI 阶段暂不接入举报提交流程。
    }

    private func toggleFavorite() {
        withAnimation(.snappy(duration: 0.2)) {
            isFavorite.toggle()
        }
    }

    private func handlePrivateChat() {
        // 完整咨询、购买和领养 SOP 后续在 IM 中完成。
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
            id: "local-message-\(UUID().uuidString)",
            authorName: currentUserName,
            avatarAssetName: currentUserAvatarAssetName,
            text: trimmedText,
            publishedAt: Date(),
            isPostAuthor: false,
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
        withAnimation(FeedDetailLayout.commentComposerAnimation) {
            selectedCommentForActions = comment
        }
    }

    private func dismissCommentActionSheet() {
        withAnimation(FeedDetailLayout.commentComposerAnimation) {
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

    private func updateNavigationIdentityOffset(_ minY: CGFloat) {
        let primaryShowThreshold: CGFloat = MHBTheme.Spacing.s8
        let primaryHideThreshold: CGFloat = MHBTheme.Spacing.s8 + MHBTheme.Spacing.s5
        let subtitleShowThreshold: CGFloat = 0
        let subtitleHideThreshold: CGFloat = MHBTheme.Spacing.s5

        let nextPrimaryVisible: Bool
        if isNavigationIdentityVisible {
            nextPrimaryVisible = minY <= primaryHideThreshold
        } else {
            nextPrimaryVisible = minY <= primaryShowThreshold
        }

        let nextSubtitleVisible: Bool
        if isNavigationSubtitleVisible {
            nextSubtitleVisible = nextPrimaryVisible && minY <= subtitleHideThreshold
        } else {
            nextSubtitleVisible = nextPrimaryVisible && minY <= subtitleShowThreshold
        }

        guard nextPrimaryVisible != isNavigationIdentityVisible ||
              nextSubtitleVisible != isNavigationSubtitleVisible
        else {
            return
        }

        withAnimation(.easeInOut(duration: 0.22)) {
            isNavigationIdentityVisible = nextPrimaryVisible
            isNavigationSubtitleVisible = nextSubtitleVisible
        }
    }
}

// SameCityCommodityDetailMissingScreen 同城商品详情缺失页面
// 核心职责：
// - 展示无法找到商品详情时的轻量占位
// - 保持系统导航返回能力可用
private struct SameCityCommodityDetailMissingScreen: View {
    var body: some View {
        Text("这条同城动态暂时不可查看")
            .font(MHBTheme.Typography.body)
            .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(MHBTheme.ColorToken.background.color)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
    }
}

// SameCityCommodityDetailLayout 同城商品详情布局参数
// 核心职责：
// - 收敛商品详情底部栏和 section 间距
// - 保持沉浸式详情页面底部内容不被操作栏遮挡
enum SameCityCommodityDetailLayout {
    static let contentHorizontalPadding: CGFloat = MHBTheme.Spacing.s5
    static let sectionSpacing: CGFloat = MHBTheme.Spacing.s6
    static let dividerHorizontalPadding: CGFloat = MHBTheme.Spacing.s5
    static let bottomPrimaryButtonHeight: CGFloat = 44
    static let bottomBarTopPadding: CGFloat = MHBTheme.Spacing.s3

    static func bottomBarReservedHeight(bottomSafeArea: CGFloat) -> CGFloat {
        bottomPrimaryButtonHeight + bottomBarTopPadding + bottomSafeArea + MHBTheme.Spacing.s6
    }
}
