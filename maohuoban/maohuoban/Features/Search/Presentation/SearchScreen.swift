import SwiftUI
import MaohuobanDesignSystem

// SearchScreen 通用搜索落地页
// 核心职责：
// - 使用系统原生搜索框承载搜索输入
// - 根据入口上下文展示宠物世界或同城热搜
struct SearchScreen: View {
    let context: SearchEntryContext

    @State private var searchText = ""
    @State private var isSearchPresented = true
    @State private var historyState = SearchHistoryState()

    var body: some View {
        ZStack {
            MHBTheme.ColorToken.cardSolid.color
                .ignoresSafeArea()

            MHBScreenScrollView {
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
        }
        .navigationTitle("搜索")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: $searchText,
            isPresented: $isSearchPresented,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: Text(context.searchPrompt)
        )
        .searchPresentationToolbarBehavior(.avoidHidingContent)
        .accessibilityIdentifier("search.screen")
    }

    private func selectKeyword(_ keyword: String) {
        searchText = keyword
        isSearchPresented = true
    }

    private func clearHistory() {
        historyState.clear()
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
