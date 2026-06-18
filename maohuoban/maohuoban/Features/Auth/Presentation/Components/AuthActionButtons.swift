import SwiftUI
import MaohuobanDesignSystem
import MaohuobanDiagnostics

// AuthPrimaryButton 认证主按钮
// 核心职责：
// - 统一登录流程主操作视觉
// - 在提交状态下展示进度指示
struct AuthPrimaryButton: View {
    let title: String
    let isLoading: Bool
    var isEnabled: Bool = true
    var accessibilityIdentifier: String? = nil
    var diagnosticsID: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: instrumentedAction) {
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

    private func instrumentedAction() {
        if let diagnosticsID {
            Task {
                await Diagnostics.record(
                    DiagnosticsSwiftUIInstrumentation.componentEvent(
                        diagnosticsID: diagnosticsID,
                        component: .button,
                        action: .tap,
                        metadata: ["component_name": .string("AuthPrimaryButton")]
                    )
                )
            }
        }
        action()
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
                .background(MHBTheme.ColorToken.separatorSoft.color, in: .circle)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}
