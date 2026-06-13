import SwiftUI
import MaohuobanDesignSystem

// HomeRootScreen 首页 Tab 根视图
// 核心职责：
// - 作为首页 Tab NavigationStack 的根内容
// - 后续在此注册 HomeRoute 的 navigationDestination
struct HomeRootScreen: View {
    let currentUserID: String?
    @State private var store = HomeDashboardStore()
    @State private var selectedPetID: String?

    init(currentUserID: String? = nil) {
        self.currentUserID = currentUserID
    }

    var body: some View {
        Group {
            switch store.phase {
            case .idle, .loading:
                HomeDashboardLoadingView()
            case .loaded(let snapshot):
                HomeDashboardLoadedView(
                    snapshot: snapshot,
                    onSelectPet: { petID in
                        selectedPetID = petID
                        Task {
                            await store.load(
                                currentUserID: currentUserID,
                                selectedPetID: petID
                            )
                        }
                    }
                )
            case .failed(let message):
                HomeDashboardErrorView(message: message) {
                    Task {
                        await store.load(
                            currentUserID: currentUserID,
                            selectedPetID: selectedPetID
                        )
                    }
                }
            }
        }
        .navigationTitle("首页")
        .task(id: currentUserID) {
            selectedPetID = nil
            await store.load(currentUserID: currentUserID)
        }
        .navigationDestination(for: HomeRoute.self) { route in
            HomeRouteDestinationScreen(
                route: route,
                currentUserID: currentUserID
            ) {
                Task {
                    await store.load(
                        currentUserID: currentUserID,
                        selectedPetID: selectedPetID
                    )
                }
            }
        }
    }
}

// HomeDashboardLoadingView 首页加载态
// 核心职责：
// - 展示首页快照加载过程
// - 保持根视图状态切换轻量
private struct HomeDashboardLoadingView: View {
    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s4) {
            ProgressView()
            Text("正在加载首页")
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MHBTheme.ColorToken.background.color)
        .accessibilityIdentifier("home.loading")
    }
}

// HomeDashboardErrorView 首页错误态
// 核心职责：
// - 展示首页加载失败原因
// - 提供显式重试入口
private struct HomeDashboardErrorView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s4) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: MHBTheme.IconSize.large, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.warning.color)

            Text(message)
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                .multilineTextAlignment(.center)

            Button("重新加载", action: onRetry)
                .font(MHBTheme.Typography.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, MHBTheme.Spacing.s5)
                .padding(.vertical, MHBTheme.Spacing.s3)
                .background(MHBTheme.ColorToken.primary.color)
                .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
        }
        .padding(MHBTheme.Spacing.s6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MHBTheme.ColorToken.background.color)
        .accessibilityIdentifier("home.error")
    }
}
