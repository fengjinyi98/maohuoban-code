import SwiftUI
import MaohuobanDesignSystem

// AuthAgreementRow 协议确认行
// 核心职责：
// - 展示用户协议和隐私政策确认状态
// - 将协议勾选作为登录提交前置条件
struct AuthAgreementRow: View {
    @Binding var isAccepted: Bool
    let onUserAgreement: () -> Void
    let onPrivacyPolicy: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: MHBTheme.Spacing.s2) {
            AuthAgreementToggleButton(isAccepted: $isAccepted)

            AuthAgreementLinks(
                onUserAgreement: onUserAgreement,
                onPrivacyPolicy: onPrivacyPolicy
            )
        }
    }
}

// AuthAgreementToggleButton 协议勾选按钮
// 核心职责：
// - 切换认证流程的协议同意状态
// - 保留 UI 测试所需可访问标识
private struct AuthAgreementToggleButton: View {
    @Binding var isAccepted: Bool

    var body: some View {
        Button {
            isAccepted.toggle()
        } label: {
            Image(systemName: isAccepted ? "checkmark.square.fill" : "square")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isAccepted ? MHBTheme.ColorToken.primary.color : MHBTheme.ColorToken.labelTertiary.color)
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("同意用户协议和隐私政策")
        .accessibilityIdentifier("auth.agreementButton")
    }
}

// AuthAgreementLinks 协议文档链接组
// 核心职责：
// - 展示用户协议与隐私政策两个独立入口
// - 将文档打开动作交还登录页容器处理
private struct AuthAgreementLinks: View {
    let onUserAgreement: () -> Void
    let onPrivacyPolicy: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Text("我已阅读并同意")
                .font(MHBTheme.Typography.caption)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)

            Button("《用户协议》", action: onUserAgreement)
                .font(MHBTheme.Typography.caption.weight(.semibold))
                .foregroundStyle(MHBTheme.ColorToken.primary.color)
                .accessibilityIdentifier("auth.userAgreementLink")

            Text("和")
                .font(MHBTheme.Typography.caption)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)

            Button("《隐私政策》", action: onPrivacyPolicy)
                .font(MHBTheme.Typography.caption.weight(.semibold))
                .foregroundStyle(MHBTheme.ColorToken.primary.color)
                .accessibilityIdentifier("auth.privacyPolicyLink")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
