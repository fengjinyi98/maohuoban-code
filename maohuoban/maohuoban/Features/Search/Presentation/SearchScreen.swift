import SwiftUI
import MaohuobanDesignSystem

// SearchScreen 通用搜索落地页
// 核心职责：
// - 使用 UIKit 原生搜索栏承载导航栏内搜索输入
// - 根据入口上下文展示宠物世界或同城热搜
struct SearchScreen: View {
    let context: SearchEntryContext

    @State private var searchText = ""
    @State private var isSearchFocused = true
    @State private var keyboardDismissRequestNonce = 0
    @State private var didRequestDismissDuringScroll = false
    @State private var historyState = SearchHistoryState()

    var body: some View {
        let searchBarConfiguration = SearchNavigationSearchBarConfiguration(context: context)

        GeometryReader { proxy in
            ZStack {
                MHBTheme.ColorToken.cardSolid.color
                    .ignoresSafeArea()

                MHBScreenScrollView {
                    ZStack(alignment: .top) {
                        MHBOutsideTapDismissLayer {
                            dismissKeyboard(reason: "blankTap")
                        }

                        VStack(spacing: 0) {
                            SearchHistorySection(
                                keywords: historyState.keywords,
                                onSelectKeyword: selectKeyword,
                                onClearHistory: clearHistory
                            )

                            SearchDividerBand()

                            SearchHotListSection(
                                title: context.hotSectionTitle,
                                keywords: SearchHotKeywordProvider.hotKeywords(for: context),
                                onSelectKeyword: selectKeyword
                            )
                        }
                        .padding(.top, MHBTheme.Spacing.s3)
                        .padding(.bottom, MHBTheme.Spacing.s8)
                    }
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height, alignment: .top)
                }
                .scrollDismissesKeyboard(.interactively)
                .onScrollPhaseChange { _, phase in
                    handleScrollPhaseChange(phase)
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .background(
            SearchNavigationSearchBar(
                text: $searchText,
                isFocused: $isSearchFocused,
                dismissRequestNonce: keyboardDismissRequestNonce,
                configuration: searchBarConfiguration,
                onSubmit: submitSearch
            )
        )
        .accessibilityIdentifier("search.screen")
    }

    private func selectKeyword(_ keyword: String) {
        searchText = keyword
        isSearchFocused = true
    }

    private func clearHistory() {
        historyState.clear()
    }

    private func submitSearch() {
        dismissKeyboard(reason: "submit")
    }

    private func dismissKeyboard(reason: String) {
        keyboardDismissRequestNonce += 1
        isSearchFocused = false
        MHBKeyboardDismissal.dismissActiveKeyboard()

        #if DEBUG
        print(
            "[DEBUG:SearchKeyboardDismiss] requested "
            + "reason=\(reason) "
            + "nonce=\(keyboardDismissRequestNonce)"
        )
        #endif
    }

    private func handleScrollPhaseChange(_ phase: ScrollPhase) {
        if phase == .idle {
            didRequestDismissDuringScroll = false
            return
        }

        guard !didRequestDismissDuringScroll else {
            return
        }

        didRequestDismissDuringScroll = true
        dismissKeyboard(reason: "scroll")
    }
}

// SearchDividerBand 搜索内容分隔带
// 核心职责：
// - 分隔历史搜索和热搜榜单
// - 保持设计稿中的浅色横向过渡
private struct SearchDividerBand: View {
    var body: some View {
        MHBTheme.ColorToken.background.color
            .frame(height: MHBTheme.Spacing.s2)
            .accessibilityHidden(true)
    }
}
