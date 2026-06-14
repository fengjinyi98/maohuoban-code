import SwiftUI
import MaohuobanDesignSystem

// HomeRootScreen 首页 Tab 根视图
// 核心职责：
// - 作为首页 Tab NavigationStack 的根内容
// - 后续在此注册 HomeRoute 的 navigationDestination
struct HomeRootScreen: View {
    let currentUserID: String?
    @State private var store = HomeDashboardStore()
    @State private var locationService = MHBLocationService()
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
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                HomeLocationToolbarButton(title: navigationLocationTitle) {
                    MHBLocationDiagnostics.homeToolbarTapped(displayName: locationService.displayName)
                    locationService.refresh()
                }
            }
        }
        .task(id: currentUserID) {
            MHBLocationDiagnostics.homeTaskStarted(currentUserID: currentUserID)
            selectedPetID = nil
            locationService.refreshIfNeeded()
            await store.load(currentUserID: currentUserID)
            MHBLocationDiagnostics.homeStoreLoaded(
                locationDisplayName: locationService.displayName,
                backendTitle: backendLocationTitle
            )
        }
        .onChange(of: locationService.displayName) { _, displayName in
            MHBLocationDiagnostics.homeDisplayNameChanged(
                displayName: displayName,
                backendTitle: backendLocationTitle
            )
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

    private var navigationLocationTitle: String {
        if let displayName = locationService.displayName {
            return displayName
        }

        return backendLocationTitle
    }

    private var backendLocationTitle: String {
        switch store.phase {
        case .loaded(let snapshot):
            let city = snapshot.identity.city?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let city, city.isEmpty == false {
                return city
            }
            return "我们的位置"
        case .idle, .loading, .failed:
            return "我们的位置"
        }
    }
}

// HomeLocationToolbarButton 首页位置切换入口
// 核心职责：
// - 在系统导航栏左侧展示当前首页位置
// - 预留位置切换点击入口
private struct HomeLocationToolbarButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: MHBTheme.Spacing.s2) {
                Image("LocationIcon")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: MHBTheme.IconSize.medium, height: MHBTheme.IconSize.medium)

                Text(title)
                    .font(MHBTheme.Typography.headline)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .layoutPriority(1)

                Image(systemName: "chevron.down")
                    .font(.system(size: MHBTheme.IconSize.small, weight: .semibold))
            }
            .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("切换位置，\(title)")
        .accessibilityIdentifier("home.locationToolbarButton")
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
