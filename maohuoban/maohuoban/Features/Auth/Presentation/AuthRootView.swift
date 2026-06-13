import SwiftUI
import MaohuobanDiagnostics
import MaohuobanDesignSystem

// AuthRootView 登录态根视图
// 核心职责：
// - 根据登录态切换认证流程与应用首页
// - 挂载全局 Toast 容器和冷启动 refresh 流程
struct AuthRootView: View {
    @Bindable var viewModel: AuthViewModel

    var body: some View {
        ZStack {
            if viewModel.isAuthenticated {
                ContentView {
                    Task { await viewModel.logout() }
                }
                .transition(.opacity)
            } else {
                AuthFlowView(viewModel: viewModel)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.25), value: viewModel.isAuthenticated)
        .mhbToast()
        .task {
            await viewModel.bootstrapSession()
        }
    }
}

// AuthFlowView 认证流程容器
// 核心职责：
// - 承载登录、验证码、账号恢复三类页面切换
// - 保持各页面只读取自身需要的状态
private struct AuthFlowView: View {
    @Bindable var viewModel: AuthViewModel

    var body: some View {
        ZStack {
            MHBTheme.ColorToken.background.color
                .ignoresSafeArea()

            switch viewModel.step {
            case .login:
                AuthLoginView(viewModel: viewModel)
            case .verification:
                AuthVerificationView(viewModel: viewModel)
            case .recovery:
                AuthRecoveryView(viewModel: viewModel)
            }
        }
        .diagnosticsScreen("auth", metadata: ["step": .string("\(viewModel.step)")])
    }
}
