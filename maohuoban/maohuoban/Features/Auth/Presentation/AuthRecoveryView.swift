import SwiftUI
import MaohuobanDesignSystem

// AuthRecoveryView 忘记密码页面
// 核心职责：
// - 发送账号恢复验证码
// - 提交验证码和新密码完成重置
struct AuthRecoveryView: View {
    @Bindable var viewModel: AuthViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s6) {
                AuthBackButton {
                    viewModel.backToLogin()
                }

                AuthPageHeading(
                    title: "忘记密码",
                    subtitle: "输入手机号，我们将发送验证码帮助你重置密码"
                )

                AuthInputField(
                    title: "手机号",
                    placeholder: "请输入手机号",
                    systemImage: "phone.fill",
                    text: $viewModel.recoveryPhone,
                    keyboardType: .numberPad,
                    accessibilityIdentifier: "auth.recovery.phoneInput"
                )

                if viewModel.hasRecoveryChallenge {
                    AuthInputField(
                        title: "验证码",
                        placeholder: "请输入验证码",
                        systemImage: "number",
                        text: recoveryCodeBinding,
                        keyboardType: .numberPad,
                        accessibilityIdentifier: "auth.recovery.codeInput"
                    )

                    AuthSecureField(
                        title: "新密码",
                        placeholder: "请输入新密码",
                        systemImage: "lock.fill",
                        text: $viewModel.recoveryPassword,
                        accessibilityIdentifier: "auth.recovery.passwordInput"
                    )
                }

                AuthPrimaryButton(
                    title: viewModel.hasRecoveryChallenge ? "重置密码" : "获取验证码",
                    isLoading: viewModel.isSubmitting,
                    accessibilityIdentifier: viewModel.hasRecoveryChallenge ? "auth.recovery.resetPasswordButton" : "auth.recovery.sendCodeButton"
                ) {
                    Task {
                        if viewModel.hasRecoveryChallenge {
                            await viewModel.resetPassword()
                        } else {
                            await viewModel.sendRecoveryCode()
                        }
                    }
                }

                Button("返回登录") {
                    viewModel.backToLogin()
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.primary.color)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("auth.recovery.returnLoginButton")

                AuthRecoverySecurityCard()

                Spacer(minLength: MHBTheme.Spacing.s8)
            }
            .padding(.horizontal, MHBTheme.Spacing.s5)
            .padding(.top, MHBTheme.Spacing.s6)
        }
        .scrollIndicators(.hidden)
    }

    private var recoveryCodeBinding: Binding<String> {
        Binding(
            get: { viewModel.recoveryCode },
            set: { newValue in
                viewModel.recoveryCode = String(newValue.filter(\.isNumber).prefix(6))
            }
        )
    }
}
