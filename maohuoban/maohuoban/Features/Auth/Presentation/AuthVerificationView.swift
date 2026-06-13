import SwiftUI
import MaohuobanDesignSystem

// AuthVerificationView 验证码页面
// 核心职责：
// - 展示 6 位验证码输入状态
// - 提交验证码完成登录
struct AuthVerificationView: View {
    @Bindable var viewModel: AuthViewModel
    @FocusState private var isCodeFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s6) {
            AuthBackButton {
                viewModel.backToLogin()
            }

            AuthPageHeading(
                title: "输入验证码",
                subtitle: "验证码已发送至 \(viewModel.maskedPhone)"
            )

            AuthCodeBoxes(code: viewModel.code)
                .overlay {
                    TextField("", text: limitedCodeBinding)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .focused($isCodeFocused)
                        .opacity(0.01)
                        .accessibilityLabel("验证码")
                        .accessibilityIdentifier("auth.verification.codeInput")
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("验证码输入")
                .accessibilityValue(viewModel.code.isEmpty ? "未输入" : "已输入 \(viewModel.code.count) 位")
                .accessibilityIdentifier("auth.verification.codeBoxes")
                .accessibilityAddTraits(.isButton)
                .onTapGesture {
                    isCodeFocused = true
                }

            AuthPrimaryButton(
                title: "验证并登录",
                isLoading: viewModel.isSubmitting,
                accessibilityIdentifier: "auth.verifyCodeButton"
            ) {
                Task { await viewModel.verifyCode() }
            }

            Text("重新发送")
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.primary.color)
                .frame(maxWidth: .infinity)
                .onTapGesture {
                    Task { await viewModel.sendPhoneCode() }
                }
                .accessibilityIdentifier("auth.resendCodeButton")

            Spacer()
        }
        .padding(.horizontal, MHBTheme.Spacing.s5)
        .padding(.top, MHBTheme.Spacing.s6)
        .onAppear {
            isCodeFocused = true
        }
    }

    private var limitedCodeBinding: Binding<String> {
        Binding(
            get: { viewModel.code },
            set: { newValue in
                viewModel.code = String(newValue.filter(\.isNumber).prefix(6))
            }
        )
    }
}
