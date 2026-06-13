import SwiftUI
import MaohuobanDesignSystem

// ProfileRootScreen 我的 Tab 根视图
// 核心职责：
// - 作为"我的"Tab NavigationStack 的根内容
// - 承载主人身份管理入口和退出登录
// - 后续在此注册 ProfileRoute 的 navigationDestination
struct ProfileRootScreen: View {
    let onLogout: () -> Void

    var body: some View {
        List {
            Section {
                Label("账号资料", systemImage: "person.text.rectangle")
                Label("身份认证", systemImage: "checkmark.shield")
                Label("订单管理", systemImage: "bag")
                Label("数据授权", systemImage: "lock.shield")
                Label("隐私设置", systemImage: "hand.raised")
            } header: {
                Text("账号管理")
            }

            Section {
                Button(role: .destructive) {
                    onLogout()
                } label: {
                    Label("退出登录", systemImage: "rectangle.portrait.and.arrow.right")
                }
            } header: {
                Text("会话")
            }
        }
        .navigationTitle("我的")
        .background(MHBTheme.ColorToken.background.color)
    }
}
