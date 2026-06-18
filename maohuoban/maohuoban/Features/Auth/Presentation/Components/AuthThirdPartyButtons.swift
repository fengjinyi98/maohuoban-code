import SwiftUI
import MaohuobanDesignSystem

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
                .shadow(color: MHBTheme.ColorToken.separatorSoft.color, radius: 8, x: 0, y: 2)
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
