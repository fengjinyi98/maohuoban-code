import SwiftUI
import MaohuobanDesignSystem

// SettingsAccountManagementScreen 账号管理页面
// 核心职责：
// - 展示当前账号和可切换账号列表
// - 在后端未接入时提供添加账号与移除账号占位入口
struct SettingsAccountManagementScreen: View {
    let username: String
    let phoneDisplayText: String

    init(
        username: String,
        phoneDisplayText: String
    ) {
        self.username = username
        self.phoneDisplayText = phoneDisplayText
    }

    var body: some View {
        MHBScreenScrollView {
            VStack(spacing: MHBTheme.Spacing.s4) {
                SettingsSection {
                    SettingsRow(
                        title: username,
                        value: "当前账号",
                        subtitle: phoneDisplayText,
                        showChevron: false
                    )
                    SettingsDivider()
                    SettingsRow(
                        title: "家人账号",
                        value: "可切换",
                        subtitle: "+86 188****0291",
                        showChevron: false
                    )
                }

                SettingsSection {
                    SettingsRow(title: "添加或注册新账号", showChevron: false, alignment: .center)
                    SettingsDivider()
                    SettingsRow(title: "管理已保存账号", showChevron: false, alignment: .center)
                }
            }
            .padding(.horizontal, MHBTheme.Spacing.s4)
            .padding(.vertical, MHBTheme.Spacing.s4)
        }
        .background(MHBTheme.ColorToken.background.color.ignoresSafeArea())
        .navigationTitle("切换账号")
        .navigationBarTitleDisplayMode(.inline)
    }
}
