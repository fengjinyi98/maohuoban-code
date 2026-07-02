import SwiftUI
import MaohuobanDesignSystem

// PetWorldNavigationHeader 宠物世界自定义导航头部
// 核心职责：
// - 在页面顶层承载频道 tab 和搜索入口
// - 为频道区提供完整屏幕宽度布局，避免系统 toolbar 压缩
struct PetWorldNavigationHeader<SearchRoute: Hashable>: View {
    @Binding var selection: PetWorldNavigationTab
    let searchRoute: SearchRoute

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            PetWorldNavigationTabBar(selection: $selection)
                .layoutPriority(1)

            Spacer(minLength: MHBTheme.Spacing.s2)

            PetWorldNavigationSearchButton(route: searchRoute)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
