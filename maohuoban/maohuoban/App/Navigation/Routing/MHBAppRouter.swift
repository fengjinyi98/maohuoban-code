import SwiftUI

// MHBAppRouter 跨 Tab 路由协调器
// 核心职责：
// - 管理当前选中的 Tab
// - 提供跨 Tab 导航能力（切换 Tab + 携带路由目标）
// - Deep link 入口骨架（后续实现 URL 解析）
@MainActor
@Observable
final class MHBAppRouter {
    var selectedTab: MHBAppTab = .home
    var tabState = MHBAppTabState()

    // MARK: - Tab 切换

    /// 切换到指定 Tab（保留各 Tab 的导航历史）
    func switchToTab(_ tab: MHBAppTab) {
        selectedTab = tab
    }

    /// 切换到指定 Tab 并重置其导航栈到根
    func switchToTabAndReset(_ tab: MHBAppTab) {
        tabState.popToRoot(for: tab)
        selectedTab = tab
    }

    // MARK: - Deep Link

    /// Deep link 入口（骨架 — 后续实现 URL scheme 解析与路由分发）
    func handleDeepLink(_ url: URL) {
        // 后续实现：
        // 1. 解析 URL path/components → 确定目标 Tab + Route
        // 2. switchToTab(targetTab)
        // 3. tabState.path(for: targetTab).append(targetRoute)
    }

    // MARK: - 便捷方法

    /// 退出登录后重置所有导航状态
    func resetAll() {
        for tab in MHBAppTab.allCases {
            tabState.popToRoot(for: tab)
        }
        selectedTab = .home
    }
}
