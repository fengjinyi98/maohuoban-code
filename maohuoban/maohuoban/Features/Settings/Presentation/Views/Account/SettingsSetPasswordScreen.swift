import SwiftUI
import MaohuobanDesignSystem

// SettingsSetPasswordScreen 设置密码页面
// 核心职责：
// - 根据密码状态展示首次设置、旧密码修改和短信重置表单
// - 通过 SettingsPasswordStore 管理 mock 提交状态
struct SettingsSetPasswordScreen: View {
    @State private var store: SettingsPasswordStore
    @State private var isCurrentPasswordVisible = false
    @State private var isNewPasswordVisible = false
    @State private var isConfirmPasswordVisible = false

    init(store: SettingsPasswordStore) {
        self._store = State(initialValue: store)
    }

    var body: some View {
        MHBScreenScrollView {
            VStack(spacing: MHBTheme.Spacing.s4) {
                if store.showsModeTabs {
                    Picker("设置密码模式", selection: $store.selectedMode) {
                        ForEach([SettingsPasswordMode.currentPassword, .smsCode]) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                SettingsPasswordInputCard(
                    store: store,
                    isCurrentPasswordVisible: $isCurrentPasswordVisible,
                    isNewPasswordVisible: $isNewPasswordVisible,
                    isConfirmPasswordVisible: $isConfirmPasswordVisible
                )

                if let error = store.errorMessage {
                    Text(error)
                        .font(MHBTheme.Typography.caption)
                        .foregroundStyle(MHBTheme.ColorToken.danger.color)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button(action: submit) {
                    Text(store.isSubmitting ? "提交中..." : "完成")
                        .font(MHBTheme.Typography.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(MHBTheme.ColorToken.primary.color)
                        .clipShape(.rect(cornerRadius: MHBTheme.Radius.large))
                }
                .disabled(store.isSubmitting)
            }
            .padding(.horizontal, MHBTheme.Spacing.s4)
            .padding(.vertical, MHBTheme.Spacing.s4)
        }
        .background(MHBTheme.ColorToken.background.color.ignoresSafeArea())
        .navigationTitle("设置密码")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func submit() {
        Task {
            await store.submit()
            showPasswordToast(success: store.didComplete)
        }
    }

    private func showPasswordToast(success: Bool) {
        guard let message = store.toastMessage else { return }
        if success {
            MHBToastPresenter().success(message)
        } else {
            MHBToastPresenter().danger(message)
        }
    }
}

// SettingsPasswordInputCard 密码输入卡片
// 核心职责：
// - 根据密码状态组合展示当前密码、短信验证码和新密码字段
// - 提供密码可见切换
struct SettingsPasswordInputCard: View {
    @Bindable var store: SettingsPasswordStore
    @Binding var isCurrentPasswordVisible: Bool
    @Binding var isNewPasswordVisible: Bool
    @Binding var isConfirmPasswordVisible: Bool

    var body: some View {
        SettingsSection {
            if store.requiresCurrentPassword {
                passwordField("当前密码", text: $store.currentPassword, isVisible: $isCurrentPasswordVisible)
                SettingsDivider()
            }
            if store.requiresSMSCode {
                HStack {
                    TextField("短信验证码", text: $store.smsCode)
                        .keyboardType(.numberPad)
                    Button(store.sendCodeButtonTitle) {
                        sendResetCode()
                    }
                    .disabled(store.isSendCodeDisabled)
                    .font(MHBTheme.Typography.callout)
                    .foregroundStyle(MHBTheme.ColorToken.primary.color)
                }
                .padding(MHBTheme.Spacing.s4)
                SettingsDivider()
            }
            passwordField("新密码", text: $store.newPassword, isVisible: $isNewPasswordVisible)
            SettingsDivider()
            passwordField("确认新密码", text: $store.confirmPassword, isVisible: $isConfirmPasswordVisible)
        }
    }

    private func passwordField(
        _ placeholder: String,
        text: Binding<String>,
        isVisible: Binding<Bool>
    ) -> some View {
        HStack {
            if isVisible.wrappedValue {
                TextField(placeholder, text: text)
            } else {
                SecureField(placeholder, text: text)
            }

            Button {
                isVisible.wrappedValue.toggle()
            } label: {
                Image(systemName: isVisible.wrappedValue ? "eye.slash" : "eye")
            }
            .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
        }
        .padding(MHBTheme.Spacing.s4)
    }

    private func sendResetCode() {
        Task {
            await store.sendResetCode()
            showCodeToast()
        }
    }

    private func showCodeToast() {
        guard let message = store.toastMessage else { return }
        if store.errorMessage == nil {
            MHBToastPresenter().success(message)
        } else {
            MHBToastPresenter().danger(message)
        }
    }
}
