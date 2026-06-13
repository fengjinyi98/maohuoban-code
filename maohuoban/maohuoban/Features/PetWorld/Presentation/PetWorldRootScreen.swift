import SwiftUI
import MaohuobanDesignSystem

// PetWorldRootScreen 宠物世界 Tab 根视图
// 核心职责：
// - 作为宠物世界 Tab NavigationStack 的根内容
// - 承载基于宠物画像的推荐流
struct PetWorldRootScreen: View {
    var body: some View {
        MHBTabPlaceholderRootScreen(
            systemImage: "globe",
            title: "宠物世界",
            subtitle: "基于宠物画像的推荐流",
            accessibilityIdentifier: "petWorld.root"
        )
    }
}
