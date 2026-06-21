import SwiftUI
import MaohuobanDiagnostics
import MaohuobanDesignSystem

// AuthRootView 登录态根视图
// 核心职责：
// - 根据登录态切换认证流程与应用主壳
// - 挂载全局 Toast 容器和冷启动 refresh 流程
struct AuthRootView: View {
    @Bindable var viewModel: AuthViewModel
    let router: MHBAppRouter
    let appAppearanceStore: AppAppearanceStore

    var body: some View {
        ZStack {
            if viewModel.isAuthenticated {
                MHBAppShell(
                    router: router,
                    currentUserID: viewModel.currentUser?.id,
                    appAppearanceStore: appAppearanceStore,
                    onLogout: handleLogout
                )
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
        .onReceive(NotificationCenter.default.publisher(for: .mhbAuthenticationInvalidated)) { notification in
            let message = notification.object as? String ?? "登录状态已过期，请重新登录"
            router.resetAll()
            viewModel.handleAuthenticationInvalidated(message: message)
        }
        .task(id: viewModel.isAuthenticated) {
            if viewModel.isAuthenticated {
                MHBKeyboardDismissal.dismissActiveKeyboard()
                try? await Task.sleep(for: .milliseconds(200))
                MHBKeyboardDismissal.dismissActiveKeyboard()
            }
        }
    }

    // handleLogout 处理退出登录事件
    // 核心职责：
    // - 清空跨 Tab 导航状态
    // - 触发认证 ViewModel 的后端登出与本地会话清理
    private func handleLogout() {
        router.resetAll()
        Task { await viewModel.logout() }
    }
}

// AuthFlowView 认证流程容器
// 核心职责：
// - 承载登录、验证码、账号恢复三类页面切换
// - 保持各页面只读取自身需要的状态
private struct AuthFlowView: View {
    @Bindable var viewModel: AuthViewModel

    var body: some View {
        NavigationStack(path: Binding(
            get: {
                switch viewModel.step {
                case .login:
                    return [] as [AuthStep]
                case .verification:
                    return [.verification]
                case .recovery:
                    return [.recovery]
                }
            },
            set: { newPath in
                if let last = newPath.last {
                    viewModel.step = last
                } else {
                    viewModel.step = .login
                }
            }
        )) {
            AuthLoginView(viewModel: viewModel)
                .navigationDestination(for: AuthStep.self) { step in
                    switch step {
                    case .login:
                        EmptyView()
                    case .verification:
                        AuthVerificationView(viewModel: viewModel)
                    case .recovery:
                        AuthRecoveryView(viewModel: viewModel)
                    }
                }
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .diagnosticsScreen("auth", metadata: ["step": .string("\(viewModel.step)")])
    }
}
