import SwiftUI
import MaohuobanDesignSystem

// PetWorldFeedList 宠物世界 Feed 列表
// 核心职责：
// - 承载宠物世界信息流纵向滚动布局
// - 通过顶部内容间距避开自定义导航头部
struct PetWorldFeedList: View {
    let cards: [PetWorldFeedItem]
    let interactionStore: PetWorldFeedInteractionStore
    let topContentInset: CGFloat
    let onMoreAction: (String, PetWorldFeedMoreAction) -> Void
    let onScrollOffsetChange: (CGFloat) -> Void
    let onScrollPhaseChange: (ScrollPhase) -> Void

    @State private var presentedMoreMenuCardID: String?
    @State private var moreButtonFrames: [String: CGRect] = [:]

    init(
        cards: [PetWorldFeedItem],
        interactionStore: PetWorldFeedInteractionStore,
        topContentInset: CGFloat,
        onMoreAction: @escaping (String, PetWorldFeedMoreAction) -> Void = { _, _ in },
        onScrollOffsetChange: @escaping (CGFloat) -> Void = { _ in },
        onScrollPhaseChange: @escaping (ScrollPhase) -> Void = { _ in }
    ) {
        self.cards = cards
        self.interactionStore = interactionStore
        self.topContentInset = topContentInset
        self.onMoreAction = onMoreAction
        self.onScrollOffsetChange = onScrollOffsetChange
        self.onScrollPhaseChange = onScrollPhaseChange
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: MHBTheme.Spacing.s8) {
                        ForEach(cards) { card in
                            PetWorldFeedCard(
                                card: card,
                                interactionState: interactionStore.interactionState(for: card),
                                onToggleLike: {
                                    interactionStore.toggleLike(cardID: card.id)
                                },
                                onMoreTap: {
                                    toggleMoreMenu(cardID: card.id)
                                }
                            )
                            .accessibilityIdentifier("petWorld.feed.card.\(card.id)")
                        }
                    }
                    .padding(.horizontal, MHBTheme.Spacing.s5)
                    .padding(.top, topContentInset)
                    .padding(.bottom, MHBTheme.Spacing.s8 + MHBTheme.Spacing.s8)
                }
                .scrollIndicators(.hidden)
                .onPreferenceChange(PetWorldFeedMoreButtonFramePreferenceKey.self) { frames in
                    moreButtonFrames = frames
                }
                .onScrollGeometryChange(for: CGFloat.self) { geometry in
                    max(geometry.contentOffset.y, 0)
                } action: { _, offset in
                    onScrollOffsetChange(offset)
                }
                .onScrollPhaseChange { _, phase in
                    if phase != .idle {
                        dismissMoreMenu()
                    }
                    onScrollPhaseChange(phase)
                }

                if presentedMoreMenuCardID != nil {
                    MHBOutsideTapDismissLayer(onDismiss: dismissMoreMenu)
                        .zIndex(1)
                }

                PetWorldFeedMoreMenuOverlay(
                    isPresented: presentedMoreMenuCardID != nil,
                    containerSize: proxy.size,
                    buttonFrame: presentedMoreMenuButtonFrame,
                    onAction: handleMoreMenuAction
                )
                .zIndex(2)
            }
            .coordinateSpace(name: PetWorldFeedCoordinateSpace.name)
        }
    }

    private var presentedMoreMenuButtonFrame: CGRect {
        guard let presentedMoreMenuCardID else {
            return .zero
        }

        return moreButtonFrames[presentedMoreMenuCardID] ?? .zero
    }

    private func toggleMoreMenu(cardID: String) {
        withAnimation(.snappy(duration: 0.22)) {
            presentedMoreMenuCardID = presentedMoreMenuCardID == cardID ? nil : cardID
        }
    }

    private func dismissMoreMenu() {
        guard presentedMoreMenuCardID != nil else {
            return
        }

        withAnimation(.snappy(duration: 0.18)) {
            presentedMoreMenuCardID = nil
        }
    }

    private func handleMoreMenuAction(_ action: PetWorldFeedMoreAction) {
        guard let cardID = presentedMoreMenuCardID else {
            return
        }

        dismissMoreMenu()
        onMoreAction(cardID, action)
    }

}
