import SwiftUI

// ProfileRootScreen 我的 Tab 根视图
// 核心职责：
// - 作为"我的"Tab NavigationStack 的根内容
// - 在重新设计前提供最小占位内容
struct ProfileRootScreen: View {
    let onLogout: () -> Void

    var body: some View {
        Text("我的页面占位")
            .accessibilityIdentifier("profile.placeholder")
            .navigationTitle("我的")
        .navigationBarTitleDisplayMode(.inline)
    }
}
