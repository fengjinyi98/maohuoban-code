import SwiftUI
import MaohuobanDesignSystem

// AuthBrandHeader 登录品牌头部
// 核心职责：
// - 展示登录页标题与副标题
// - 保持认证首页首屏层级简洁
struct AuthBrandHeader: View {
    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s2) {
            Text("欢迎来到毛伙伴")
                .font(MHBTheme.Typography.title)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

            Text("让每只毛孩子被更好的记录与陪伴")
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, MHBTheme.Spacing.s4)
    }
}

// AuthPageHeading 认证页面标题
// 核心职责：
// - 统一验证码页和账号恢复页标题样式
// - 保持正文说明文本的层级一致
struct AuthPageHeading: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
            Text(title)
                .font(MHBTheme.Typography.title)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

            Text(subtitle)
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
        }
    }
}

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
        .background(Color.black.opacity(0.02), in: .rect(cornerRadius: MHBTheme.Radius.medium))
        .overlay {
            RoundedRectangle(cornerRadius: MHBTheme.Radius.medium)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
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
        .background(Color.black.opacity(0.02), in: .rect(cornerRadius: MHBTheme.Radius.medium))
        .overlay {
            RoundedRectangle(cornerRadius: MHBTheme.Radius.medium)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        }
    }
}

// AuthPrimaryButton 认证主按钮
// 核心职责：
// - 统一登录流程主操作视觉
// - 在提交状态下展示进度指示
struct AuthPrimaryButton: View {
    let title: String
    let isLoading: Bool
    var isEnabled: Bool = true
    var accessibilityIdentifier: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: MHBTheme.Spacing.s2) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                }
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(buttonColor, in: .rect(cornerRadius: MHBTheme.Radius.medium))
            .shadow(color: shadowColor, radius: 14, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier ?? "")
        .disabled(!canInteract)
        .opacity(canInteract ? 1 : 0.78)
    }

    private var canInteract: Bool {
        isEnabled && !isLoading
    }

    private var buttonColor: Color {
        MHBTheme.ColorToken.primary.color.opacity(canInteract ? 1 : 0.42)
    }

    private var shadowColor: Color {
        MHBTheme.ColorToken.primary.color.opacity(canInteract ? 0.25 : 0)
    }
}

// AuthModeSwitchRow 登录模式切换行
// 核心职责：
// - 在验证码登录和密码登录之间切换
// - 暴露忘记密码入口
struct AuthModeSwitchRow: View {
    let mode: AuthMode
    let onToggle: () -> Void
    let onRecovery: () -> Void

    var body: some View {
        HStack {
            Button(mode == .phoneCode ? "密码登录" : "验证码登录", action: onToggle)
                .font(MHBTheme.Typography.callout.weight(.semibold))
                .foregroundStyle(MHBTheme.ColorToken.primary.color)
                .accessibilityIdentifier("auth.modeSwitchButton")

            Spacer()

            if mode == .password {
                Button("忘记密码", action: onRecovery)
                    .font(MHBTheme.Typography.callout)
                    .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
                    .accessibilityIdentifier("auth.recoveryButton")
            }
        }
    }
}

// AuthThirdPartyButtons 第三方登录入口
// 核心职责：
// - 提供微信和 Apple 登录占位入口
// - 与后端 TODO 契约保持可接入状态
struct AuthThirdPartyButtons: View {
    let isSubmitting: Bool
    let onWechat: () -> Void
    let onApple: () -> Void

    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s4) {
            HStack(spacing: MHBTheme.Spacing.s3) {
                Rectangle()
                    .fill(MHBTheme.ColorToken.separator.color)
                    .frame(height: 0.5)
                Text("第三方快捷登录")
                    .font(MHBTheme.Typography.caption)
                    .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
                    .tracking(1)
                Rectangle()
                    .fill(MHBTheme.ColorToken.separator.color)
                    .frame(height: 0.5)
            }

            HStack(spacing: MHBTheme.Spacing.s5) {
                AuthCircularIconButton(
                    assetName: "WechatIcon",
                    accessibilityIdentifier: "auth.wechatButton",
                    action: onWechat
                )
                AuthCircularIconButton(
                    systemImage: "apple.logo",
                    accessibilityIdentifier: "auth.appleButton",
                    action: onApple
                )
            }
            .disabled(isSubmitting)

            Text("未注册手机号验证后将自动注册")
                .font(MHBTheme.Typography.caption)
                .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
        }
        .padding(.top, MHBTheme.Spacing.s8)
    }
}

// AuthCircularIconButton 圆形图标按钮
// 核心职责：
// - 渲染第三方登录图标按钮
// - 保持可点击区域稳定
struct AuthCircularIconButton: View {
    let systemImage: String?
    let assetName: String?
    var accessibilityIdentifier: String? = nil
    let action: () -> Void

    init(
        systemImage: String,
        accessibilityIdentifier: String? = nil,
        action: @escaping () -> Void
    ) {
        self.systemImage = systemImage
        self.assetName = nil
        self.accessibilityIdentifier = accessibilityIdentifier
        self.action = action
    }

    init(
        assetName: String,
        accessibilityIdentifier: String? = nil,
        action: @escaping () -> Void
    ) {
        self.systemImage = nil
        self.assetName = assetName
        self.accessibilityIdentifier = accessibilityIdentifier
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            icon
                .frame(width: 44, height: 44)
                .background(MHBTheme.ColorToken.cardSolid.color, in: .circle)
                .overlay {
                    Circle()
                        .stroke(MHBTheme.ColorToken.cardBorder.color, lineWidth: 0.5)
                }
                .shadow(color: .black.opacity(0.03), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier ?? "")
    }

    @ViewBuilder
    private var icon: some View {
        if let assetName {
            Image(assetName)
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
        } else if let systemImage {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .frame(width: 24, height: 24)
        }
    }
}

// AuthBackButton 返回按钮
// 核心职责：
// - 提供验证码页和账号恢复页的统一返回入口
// - 保持圆形触控区域和图标风格一致
struct AuthBackButton: View {
    var accessibilityIdentifier: String = "auth.backButton"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .frame(width: 32, height: 32)
                .background(Color.black.opacity(0.02), in: .circle)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

// AuthCodeBoxes 验证码数字框
// 核心职责：
// - 展示 6 位验证码输入状态
// - 通过稳定格子尺寸避免输入时布局跳动
struct AuthCodeBoxes: View {
    let code: String

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s2) {
            ForEach(0..<6, id: \.self) { index in
                AuthCodeBox(character: character(at: index), isActive: code.count == index)
            }
        }
    }

    private func character(at index: Int) -> String {
        guard index < code.count else { return "" }
        let offset = code.index(code.startIndex, offsetBy: index)
        return String(code[offset])
    }
}

// AuthCodeBox 单个验证码格子
// 核心职责：
// - 渲染验证码单个数字或当前焦点
// - 保持固定宽高比例
struct AuthCodeBox: View {
    let character: String
    let isActive: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: MHBTheme.Radius.small)
                .fill(isActive ? MHBTheme.ColorToken.cardSolid.color : Color.black.opacity(0.02))
                .overlay {
                    RoundedRectangle(cornerRadius: MHBTheme.Radius.small)
                        .stroke(isActive ? MHBTheme.ColorToken.primary.color : Color.black.opacity(0.05), lineWidth: 1)
                }
                .shadow(color: isActive ? MHBTheme.ColorToken.primary.color.opacity(0.1) : .clear, radius: 6, x: 0, y: 0)

            Text(character)
                .font(MHBTheme.Typography.title)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: .infinity)
    }
}

// AuthRecoverySecurityCard 忘记密码安全提示卡
// 核心职责：
// - 对齐设计稿中的安全图形区域
// - 表达重置密码流程的安全感
struct AuthRecoverySecurityCard: View {
    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s2) {
            Image(systemName: "lock.shield")
                .font(.system(size: 36, weight: .regular))
                .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)

            Text("重置密码安全验证")
                .font(MHBTheme.Typography.caption)
                .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
        .background(MHBTheme.ColorToken.primaryBackgroundSoft.color, in: .rect(cornerRadius: MHBTheme.Radius.extraLarge))
        .overlay {
            RoundedRectangle(cornerRadius: MHBTheme.Radius.extraLarge)
                .stroke(MHBTheme.ColorToken.separator.color, lineWidth: 0.5)
        }
        .padding(.top, MHBTheme.Spacing.s8)
    }
}
