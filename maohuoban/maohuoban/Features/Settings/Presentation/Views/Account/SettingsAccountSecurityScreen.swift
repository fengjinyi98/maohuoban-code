import SwiftUI
import MaohuobanDesignSystem

// SettingsAccountSecurityScreen 账号与安全页面
// 核心职责：
// - 展示手机、密码、社交账号和认证状态
// - 提供设备管理、密码设置和认证页面入口
struct SettingsAccountSecurityScreen: View {
    let phoneDisplayText: String
    let passwordStatusText: String
    let rememberLoginEnabled: Bool
    let onRememberLoginChange: (Bool) -> Void
    let onSetPassword: () -> Void
    let onRealNameAuth: () -> Void
    let onOfficialVerification: () -> Void
    let onDeviceManagement: () -> Void

    @State private var isRememberLogin: Bool
    @State private var isPhoneAlertPresented = false

    init(
        phoneDisplayText: String,
        passwordStatusText: String,
        rememberLoginEnabled: Bool,
        onRememberLoginChange: @escaping (Bool) -> Void,
        onSetPassword: @escaping () -> Void,
        onRealNameAuth: @escaping () -> Void,
        onOfficialVerification: @escaping () -> Void,
        onDeviceManagement: @escaping () -> Void
    ) {
        self.phoneDisplayText = phoneDisplayText
        self.passwordStatusText = passwordStatusText
        self.rememberLoginEnabled = rememberLoginEnabled
        self.onRememberLoginChange = onRememberLoginChange
        self.onSetPassword = onSetPassword
        self.onRealNameAuth = onRealNameAuth
        self.onOfficialVerification = onOfficialVerification
        self.onDeviceManagement = onDeviceManagement
        self._isRememberLogin = State(initialValue: rememberLoginEnabled)
    }

    var body: some View {
        MHBScreenScrollView {
            VStack(spacing: MHBTheme.Spacing.s4) {
                SettingsSection {
                    SettingsRow(title: "手机号", value: phoneDisplayText) {
                        isPhoneAlertPresented = true
                    }
                    SettingsDivider()
                    SettingsRow(title: "登录密码", value: passwordStatusText, action: onSetPassword)
                }

                SettingsSection {
                    SettingsRow(title: "微信账号", value: "未绑定")
                    SettingsDivider()
                    SettingsRow(title: "QQ账号", value: "未绑定")
                    SettingsDivider()
                    SettingsRow(title: "Apple账号", value: "未绑定")
                }

                SettingsSection {
                    SettingsRow(title: "实名认证", value: "未认证", action: onRealNameAuth)
                    SettingsDivider()
                    SettingsRow(title: "官方认证", value: "未认证", subtitle: "个人职业资质、机构、企业认证", action: onOfficialVerification)
                }

                SettingsSection {
                    SettingsToggleRow(title: "记住登录信息", isOn: $isRememberLogin)
                    SettingsDivider()
                    SettingsRow(title: "登录设备管理", action: onDeviceManagement)
                }

                SettingsSection {
                    SettingsRow(title: "账号找回", subtitle: "无法登录其他账号，通过该方式找回并登录")
                }

                SettingsSection {
                    SettingsRow(title: "专业号", value: "未升级")
                }

                SettingsSection {
                    SettingsRow(title: "注销账号")
                }
            }
            .padding(.horizontal, MHBTheme.Spacing.s4)
            .padding(.vertical, MHBTheme.Spacing.s4)
        }
        .background(MHBTheme.ColorToken.background.color.ignoresSafeArea())
        .navigationTitle("账号与安全")
        .navigationBarTitleDisplayMode(.inline)
        .alert("更换绑定的手机号？", isPresented: $isPhoneAlertPresented) {
            Button("取消", role: .cancel) { }
            Button("继续更换", role: .destructive) { }
        } message: {
            Text("一个毛伙伴号 30 天内只能更换一次手机号")
        }
        .onChange(of: isRememberLogin) { _, newValue in
            onRememberLoginChange(newValue)
        }
    }
}
