import SwiftUI
import MaohuobanDesignSystem

// SettingsDarkModeScreen 深色模式设置页面
// 核心职责：
// - 提供深色模式和跟随系统开关
// - 将用户选择写入真实 App 外观偏好
struct SettingsDarkModeScreen: View {
    let store: AppAppearanceStore

    var body: some View {
        MHBScreenScrollView {
            SettingsSection {
                SettingsToggleRow(title: "深色模式", isOn: darkModeBinding)
                SettingsDivider()
                SettingsToggleRow(title: "跟随系统设置", subtitle: "开启后根据系统设置同步切换深/浅模式", isOn: followsSystemBinding)
            }
            .padding(.horizontal, MHBTheme.Spacing.s4)
            .padding(.vertical, MHBTheme.Spacing.s4)
        }
        .background(MHBTheme.ColorToken.background.color.ignoresSafeArea())
        .navigationTitle("深色模式")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var darkModeBinding: Binding<Bool> {
        Binding(
            get: { store.isDarkModeEnabled },
            set: { isEnabled in
                store.setDarkModeEnabled(isEnabled)
            }
        )
    }

    private var followsSystemBinding: Binding<Bool> {
        Binding(
            get: { store.followsSystem },
            set: { followsSystem in
                store.setFollowsSystem(followsSystem)
            }
        )
    }
}
