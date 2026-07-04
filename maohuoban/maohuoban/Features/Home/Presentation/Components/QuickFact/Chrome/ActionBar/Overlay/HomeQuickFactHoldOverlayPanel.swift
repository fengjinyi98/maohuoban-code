import SwiftUI
import MaohuobanDesignSystem

// HomeQuickFactHoldOverlayPanel 快捷事实确认浮层面板
// 核心职责：
// - 组合中心进度环、图标、文案和完成动效
// - 根据确认阶段切换视觉强度
struct HomeQuickFactHoldOverlayPanel: View {
    let state: HomeQuickFactHoldOverlayState

    var body: some View {
        ZStack {
            HomeQuickFactHoldOverlayAura(state: state)

            VStack(spacing: MHBTheme.Spacing.s4) {
                HomeQuickFactHoldOverlayRing(state: state)

                VStack(spacing: MHBTheme.Spacing.s1) {
                    Text(state.title)
                        .font(MHBTheme.Typography.headline.weight(.bold))
                        .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

                    Text(state.subtitle)
                        .font(MHBTheme.Typography.callout.weight(.semibold))
                        .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                }
            }
            .padding(.horizontal, MHBTheme.Spacing.s6)
            .padding(.vertical, MHBTheme.Spacing.s6)
        }
        .background(.regularMaterial, in: .rect(cornerRadius: MHBTheme.Radius.extraExtraLarge))
        .overlay {
            RoundedRectangle(cornerRadius: MHBTheme.Radius.extraExtraLarge, style: .continuous)
                .stroke(state.accentColor.opacity(borderOpacity), lineWidth: 1)
        }
        .shadow(color: state.accentColor.opacity(0.28), radius: 34, x: 0, y: 14)
        .scaleEffect(state.phase == .completed ? 1.04 : 1)
    }

    private var borderOpacity: Double {
        switch state.phase {
        case .holding:
            0.24
        case .cancelled:
            0.18
        case .completed:
            0.42
        }
    }
}

// HomeQuickFactHoldOverlayAura 快捷事实浮层氛围光
// 核心职责：
// - 为中心确认面板提供轻量仪式感背景
// - 跟随完成阶段增强强调色扩散
private struct HomeQuickFactHoldOverlayAura: View {
    let state: HomeQuickFactHoldOverlayState

    var body: some View {
        ZStack {
            Circle()
                .fill(state.accentColor.opacity(auraOpacity))
                .frame(width: 190, height: 190)
                .blur(radius: 24)

            Circle()
                .stroke(state.accentColor.opacity(auraStrokeOpacity), lineWidth: 18)
                .frame(width: 164, height: 164)
                .scaleEffect(state.phase == .completed ? 1.18 : 0.92)
        }
    }

    private var auraOpacity: Double {
        switch state.phase {
        case .holding:
            0.1
        case .cancelled:
            0.06
        case .completed:
            0.2
        }
    }

    private var auraStrokeOpacity: Double {
        switch state.phase {
        case .holding:
            0.08
        case .cancelled:
            0.04
        case .completed:
            0.18
        }
    }
}
