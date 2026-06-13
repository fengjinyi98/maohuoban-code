import SwiftUI
import MaohuobanDesignSystem

// AuthLoginView 登录首页
// 核心职责：
// - 展示手机号验证码登录与密码登录表单
// - 承接第三方登录 TODO 入口和协议勾选
struct AuthLoginView: View {
    @Bindable var viewModel: AuthViewModel
    @State private var presentedLegalKind: LegalDocumentKind?

    var body: some View {
        ScrollView {
            VStack(spacing: MHBTheme.Spacing.s6) {
                AuthBrandHeader()

                AuthLoginForm(
                    viewModel: viewModel,
                    onOpenLegalDocument: { kind in
                        presentedLegalKind = kind
                    }
                )

                AuthThirdPartyButtons(
                    isSubmitting: viewModel.isSubmitting,
                    onWechat: {
                        Task { await viewModel.oauth(provider: "wechat") }
                    },
                    onApple: {
                        Task { await viewModel.oauth(provider: "apple") }
                    }
                )
            }
            .padding(.horizontal, MHBTheme.Spacing.s5)
            .padding(.top, MHBTheme.Spacing.s8)
            .padding(.bottom, MHBTheme.Spacing.s6)
        }
        .scrollIndicators(.hidden)
        .navigationDestination(item: $presentedLegalKind) { kind in
            LegalDocumentView(kind: kind)
        }
        .background(MHBTheme.ColorToken.background.color.ignoresSafeArea())
        .navigationTitle("")
    }
}

// AuthLoginForm 登录表单
// 核心职责：
// - 绑定手机号、密码、登录模式和协议状态
// - 将提交动作转发给 ViewModel
private struct AuthLoginForm: View {
    @Bindable var viewModel: AuthViewModel
    let onOpenLegalDocument: (LegalDocumentKind) -> Void

    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s4) {
            AuthInputField(
                title: "手机号",
                placeholder: "请输入手机号",
                systemImage: "phone.fill",
                text: $viewModel.phone,
                keyboardType: .numberPad,
                accessibilityIdentifier: "auth.phoneInput"
            )

            if viewModel.mode == .password {
                AuthSecureField(
                    title: "密码",
                    placeholder: "请输入密码",
                    systemImage: "lock.fill",
                    text: $viewModel.password,
                    accessibilityIdentifier: "auth.passwordInput"
                )
            }

            AuthModeSwitchRow(
                mode: viewModel.mode,
                onToggle: viewModel.toggleMode,
                onRecovery: viewModel.showRecovery
            )

            AuthPrimaryButton(
                title: viewModel.mode == .phoneCode ? "获取验证码" : "登录",
                isLoading: viewModel.isSubmitting,
                isEnabled: viewModel.isLoginPhoneValid,
                accessibilityIdentifier: viewModel.mode == .phoneCode ? "auth.sendCodeButton" : "auth.passwordLoginButton"
            ) {
                Task {
                    if viewModel.mode == .phoneCode {
                        await viewModel.sendPhoneCode()
                    } else {
                        await viewModel.passwordLogin()
                    }
                }
            }

            AuthAgreementRow(
                isAccepted: $viewModel.isAgreementAccepted,
                onUserAgreement: {
                    onOpenLegalDocument(.userAgreement)
                },
                onPrivacyPolicy: {
                    onOpenLegalDocument(.privacyPolicy)
                }
            )
        }
    }
}
