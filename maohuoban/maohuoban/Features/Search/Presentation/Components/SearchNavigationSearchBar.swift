import SwiftUI
import MaohuobanDesignSystem

// SearchNavigationSearchBar 搜索页导航栏搜索框
// 核心职责：
// - 将搜索页上下文转换为导航栏搜索框安装参数
// - 将搜索输入、焦点和提交事件转交基础设施桥接组件
struct SearchNavigationSearchBar: View {
    @Binding var text: String
    @Binding var isFocused: Bool

    let dismissRequestNonce: Int
    let configuration: SearchNavigationSearchBarConfiguration
    let onSubmit: () -> Void

    var body: some View {
        MHBNavigationSearchBarInstaller(
            text: $text,
            isFocused: $isFocused,
            dismissRequestNonce: dismissRequestNonce,
            prompt: configuration.prompt,
            tintColor: MHBTheme.ColorToken.primary.uiColor,
            textColor: MHBTheme.ColorToken.labelPrimary.uiColor,
            accessibilityIdentifier: "search.navigation.searchBar",
            onSubmit: onSubmit
        )
        .frame(width: 0, height: 0)
        .accessibilityHidden(true)
    }
}
