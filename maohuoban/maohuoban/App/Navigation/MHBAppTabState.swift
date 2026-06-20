import SwiftUI

// MHBAppTabState 各 Tab 导航路径管理器
// 核心职责：
// - 持有每个 Tab 独立的 NavigationPath
// - 声明式推导 TabBar 显隐状态
// - 提供路径重置能力
@MainActor
@Observable
final class MHBAppTabState {
    var homePath = NavigationPath()
    var petWorldPath = NavigationPath()
    var sameCityPath = NavigationPath()
    var messagePath = NavigationPath()
    var profilePath = NavigationPath()

    /// 获取指定 Tab 的导航路径
    func path(for tab: MHBAppTab) -> NavigationPath {
        switch tab {
        case .home:     homePath
        case .petWorld: petWorldPath
        case .sameCity: sameCityPath
        case .message:  messagePath
        case .profile:  profilePath
        }
    }

    /// 获取指定 Tab 导航路径的 Binding（供 NavigationStack 使用）
    func binding(for tab: MHBAppTab) -> Binding<NavigationPath> {
        Binding(
            get: { [weak self] in
                guard let self else { return NavigationPath() }
                return self.path(for: tab)
            },
            set: { [weak self] newPath in
                guard let self else { return }
                switch tab {
                case .home:     self.homePath = newPath
                case .petWorld: self.petWorldPath = newPath
                case .sameCity: self.sameCityPath = newPath
                case .message:  self.messagePath = newPath
                case .profile:  self.profilePath = newPath
                }
            }
        )
    }

    /// 追加我的 Tab 导航目标
    func appendProfileRoute(_ route: ProfileRoute) {
        profilePath.append(route)
    }

    /// 追加宠物世界 Tab 导航目标
    func appendPetWorldRoute(_ route: PetWorldRoute) {
        petWorldPath.append(route)
    }

    /// 路径为空时显示 TabBar，非空时在 push 页面中隐藏
    func shouldShowTabBar(for tab: MHBAppTab) -> Bool {
        path(for: tab).isEmpty
    }

    /// 重置指定 Tab 的导航栈到根
    func popToRoot(for tab: MHBAppTab) {
        switch tab {
        case .home:     homePath = NavigationPath()
        case .petWorld: petWorldPath = NavigationPath()
        case .sameCity: sameCityPath = NavigationPath()
        case .message:  messagePath = NavigationPath()
        case .profile:  profilePath = NavigationPath()
        }
    }
}
