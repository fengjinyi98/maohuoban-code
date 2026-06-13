import SwiftUI
import MaohuobanDesignSystem

// SameCityRootScreen 同城 Tab 根视图
// 核心职责：
// - 作为同城 Tab NavigationStack 的根内容
// - 承载本地服务入口（医院/猫舍/宠物店）
struct SameCityRootScreen: View {
    var body: some View {
        MHBTabPlaceholderRootScreen(
            systemImage: "map.fill",
            title: "同城",
            subtitle: "本地服务 · 医院 / 猫舍 / 宠物店",
            accessibilityIdentifier: "sameCity.root"
        )
    }
}
