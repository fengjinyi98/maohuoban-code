import SwiftUI
import MaohuobanDesignSystem

// AuthInputField 认证文本输入框
// 核心职责：
// - 统一手机号、验证码等输入样式
// - 使用系统图标提示字段含义
struct AuthInputField: View {
    let title: String
    let placeholder: String
    let systemImage: String
    @Binding var text: String
    let keyboardType: UIKeyboardType
    var accessibilityIdentifier: String? = nil

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s3) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
                .frame(width: 20)

            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(MHBTheme.Typography.body)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .accessibilityLabel(title)
                .accessibilityIdentifier(accessibilityIdentifier ?? "")
        }
        .frame(height: 48)
        .padding(.horizontal, MHBTheme.Spacing.s4)
        .background(MHBTheme.ColorToken.separatorSoft.color, in: .rect(cornerRadius: MHBTheme.Radius.medium))
        .overlay {
            RoundedRectangle(cornerRadius: MHBTheme.Radius.medium)
                .stroke(MHBTheme.ColorToken.separator.color, lineWidth: 1)
        }
    }
}

// AuthSecureField 认证密码输入框
// 核心职责：
// - 统一密码字段样式
// - 使用 SecureField 保护明文输入
struct AuthSecureField: View {
    let title: String
    let placeholder: String
    let systemImage: String
    @Binding var text: String
    var accessibilityIdentifier: String? = nil

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s3) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
                .frame(width: 20)

            SecureField(placeholder, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(MHBTheme.Typography.body)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .accessibilityLabel(title)
                .accessibilityIdentifier(accessibilityIdentifier ?? "")
        }
        .frame(height: 48)
        .padding(.horizontal, MHBTheme.Spacing.s4)
        .background(MHBTheme.ColorToken.separatorSoft.color, in: .rect(cornerRadius: MHBTheme.Radius.medium))
        .overlay {
            RoundedRectangle(cornerRadius: MHBTheme.Radius.medium)
                .stroke(MHBTheme.ColorToken.separator.color, lineWidth: 1)
        }
    }
}
