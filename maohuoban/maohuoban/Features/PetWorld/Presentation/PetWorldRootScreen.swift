import SwiftUI
import MaohuobanDesignSystem

// PetWorldRootScreen 宠物世界 Tab 根视图
// 核心职责：
// - 承载宠物世界首页信息流 UI
// - 以当前宠物为推荐主体展示宠物事件流
struct PetWorldRootScreen: View {
    @State private var selectedTab = PetWorldFeedTab.recommended

    private let snapshot = PetWorldMockFeed.snapshot

    var body: some View {
        ZStack(alignment: .top) {
            PetWorldFeedPager(
                snapshot: snapshot,
                selectedTab: $selectedTab,
                topContentInset: PetWorldFeedLayout.pageTopContentInset
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: 0) {
                PetWorldFeedTabs(
                    tabs: snapshot.tabs,
                    selectedTab: $selectedTab
                )
            }
            .padding(.top, PetWorldFeedLayout.tabTopPadding)
            .zIndex(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MHBTheme.ColorToken.background.color.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                PetWorldSearchButton()
            }

            ToolbarItem(placement: .principal) {
                PetWorldPetSwitcherButton(petName: snapshot.selectedPetName)
            }

            ToolbarItem(placement: .topBarTrailing) {
                PetWorldPublishButton()
            }
        }
        .accessibilityIdentifier("petWorld.root")
    }
}

// PetWorldFeedLayout 宠物世界首页布局常量
// 核心职责：
// - 统一固定频道栏和滚动内容之间的垂直关系
// - 让内容起始位置避开频道栏，滚动时仍可进入并滚出顶层视窗
private enum PetWorldFeedLayout {
    static let tabTopPadding: CGFloat = MHBTheme.Spacing.s4
    static let tabHeight: CGFloat = 50
    static let tabBottomPadding: CGFloat = MHBTheme.Spacing.s2

    static let pageTopContentInset: CGFloat = tabTopPadding + tabHeight + tabBottomPadding
}

// PetWorldSearchButton 宠物世界搜索入口
// 核心职责：
// - 承载宠物世界导航栏左侧搜索动作
// - 使用系统导航栏原生按钮承载，避免重复玻璃层
private struct PetWorldSearchButton: View {
    var body: some View {
        Button {
            // TODO: 接入宠物世界搜索。
        } label: {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("搜索")
    }
}

// PetWorldPetSwitcherButton 宠物世界当前宠物切换入口
// 核心职责：
// - 在系统导航栏标题位置展示当前推荐主体
// - 为后续多宠切换菜单保留入口
private struct PetWorldPetSwitcherButton: View {
    let petName: String

    var body: some View {
        Button {
            // TODO: 接入宠物切换菜单。
        } label: {
            HStack(spacing: MHBTheme.Spacing.s1) {
                Text("为 \(petName) 推荐")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
            }
            .padding(.horizontal, MHBTheme.Spacing.s3)
            .frame(height: 36)
            .glassEffect(.regular.interactive(), in: .capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("切换推荐宠物")
    }
}

// PetWorldPublishButton 宠物世界发布入口
// 核心职责：
// - 承载宠物事件发布动作
// - 使用系统导航栏原生按钮承载，避免重复玻璃层
private struct PetWorldPublishButton: View {
    var body: some View {
        Button {
            // TODO: 接入宠物事件发布流程。
        } label: {
            Text("发布")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.primary.color)
                .padding(.horizontal, MHBTheme.Spacing.s3)
                .frame(height: 36)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("发布")
    }
}
