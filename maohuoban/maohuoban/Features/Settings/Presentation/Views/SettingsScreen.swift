import SwiftUI
import MaohuobanDesignSystem

// SettingsScreen 设置首页
// 核心职责：
// - 展示账号、安全、通用、隐私和支持入口
// - 承接切换账号、退出登录和地址管理等点击事件
struct SettingsScreen: View {
    let username: String
    let onLogout: () -> Void
    let onSwitchAccount: () -> Void
    let onStorageSpace: () -> Void
    let onAccountSecurity: () -> Void
    let onGeneralSettings: () -> Void
    let onNotificationSettings: () -> Void
    let onPrivacySettings: () -> Void
    let onAddressList: () -> Void

    @State private var isLogoutSheetPresented = false
    @State private var appStorageText = "计算中..."

    var body: some View {
        MHBScreenScrollView {
            VStack(spacing: MHBTheme.Spacing.s4) {
                SettingsSection {
                    SettingsRow(systemImage: "person.circle", title: "账号与安全", action: onAccountSecurity)
                    SettingsDivider(leading: 56)
                    SettingsRow(systemImage: "gearshape", title: "通用设置", action: onGeneralSettings)
                    SettingsDivider(leading: 56)
                    SettingsRow(systemImage: "bell", title: "通知设置", action: onNotificationSettings)
                    SettingsDivider(leading: 56)
                    SettingsRow(systemImage: "lock", title: "隐私设置", action: onPrivacySettings)
                }

                SettingsSection {
                    SettingsRow(systemImage: "trash", title: "存储空间", value: appStorageText, action: onStorageSpace)
                    SettingsDivider(leading: 56)
                    SettingsRow(systemImage: "map", title: "收货地址", action: onAddressList)
                    SettingsDivider(leading: 56)
                    SettingsRow(systemImage: "square.grid.2x2", title: "添加小组件")
                    SettingsDivider(leading: 56)
                    SettingsRow(systemImage: "umbrella", title: "未成年人模式", value: "未开启")
                }

                SettingsSection {
                    SettingsRow(systemImage: "headphones", title: "帮助与客服")
                    SettingsDivider(leading: 56)
                    SettingsRow(systemImage: "info.circle", title: "关于毛伙伴")
                }

                SettingsSection {
                    SettingsRow(title: "切换账号", showChevron: false, alignment: .center, action: onSwitchAccount)
                    SettingsDivider()
                    SettingsRow(title: "退出登录", showChevron: false, alignment: .center) {
                        isLogoutSheetPresented = true
                    }
                    .accessibilityIdentifier("settings.logoutRow")
                }

                SettingsFooterLinks()
                    .padding(.top, MHBTheme.Spacing.s4)
            }
            .padding(.horizontal, MHBTheme.Spacing.s4)
            .padding(.vertical, MHBTheme.Spacing.s4)
        }
        .background(MHBTheme.ColorToken.background.color.ignoresSafeArea())
        .accessibilityIdentifier("settings.scrollView")
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .sheet(isPresented: $isLogoutSheetPresented) {
            SettingsLogoutSheet(
                username: username,
                onLogout: {
                    isLogoutSheetPresented = false
                    onLogout()
                },
                onSwitchAccount: {
                    isLogoutSheetPresented = false
                    onSwitchAccount()
                },
                onCancel: {
                    isLogoutSheetPresented = false
                }
            )
            .presentationDetents([.height(250)])
            .presentationDragIndicator(.visible)
        }
        .task {
            let snapshot = await SettingsStorageCalculator.calculate()
            appStorageText = snapshot.appTotal.settingsStorageFormatted
        }
    }
}

// SettingsLogoutSheet 退出登录底部确认面板
// 核心职责：
// - 展示退出账号确认文案和操作按钮
// - 将退出、切换和取消转发到页面事件边界
private struct SettingsLogoutSheet: View {
    let username: String
    let onLogout: () -> Void
    let onSwitchAccount: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s3) {
            VStack(spacing: 0) {
                Text(SettingsLogoutSheetMessageBuilder.confirmationMessage(username: username))
                    .font(MHBTheme.Typography.callout)
                    .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
                    .padding(.top, MHBTheme.Spacing.s5)
                    .padding(.bottom, MHBTheme.Spacing.s4)

                SettingsDivider()

                Button("切换账号", action: onSwitchAccount)
                    .font(MHBTheme.Typography.headline)
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)

                SettingsDivider()

                Button("退出登录", action: onLogout)
                    .font(MHBTheme.Typography.headline)
                    .foregroundStyle(MHBTheme.ColorToken.danger.color)
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .accessibilityIdentifier("settings.logoutConfirmButton")
            }
            .background(MHBTheme.ColorToken.cardSolid.color)
            .clipShape(.rect(cornerRadius: MHBTheme.Radius.extraExtraLarge))

            Button("取消", action: onCancel)
                .font(MHBTheme.Typography.headline)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(MHBTheme.ColorToken.cardSolid.color)
                .clipShape(.rect(cornerRadius: MHBTheme.Radius.extraExtraLarge))
        }
        .padding(.horizontal, MHBTheme.Spacing.s4)
        .padding(.vertical, MHBTheme.Spacing.s3)
        .background(MHBTheme.ColorToken.background.color)
    }
}

// SettingsFooterLinks 设置页底部协议链接
// 核心职责：
// - 展示旧项目底部法务链接文本
// - 保持设置首页信息层级完整
private struct SettingsFooterLinks: View {
    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s2) {
            HStack(spacing: MHBTheme.Spacing.s3) {
                Text("《个人信息收集清单》")
                Text("《第三方信息共享清单》")
            }
            HStack(spacing: MHBTheme.Spacing.s3) {
                Text("《毛伙伴用户服务协议》")
                Text("《毛伙伴用户隐私政策》")
            }
        }
        .font(MHBTheme.Typography.section)
        .foregroundStyle(MHBTheme.ColorToken.primary.color)
    }
}
