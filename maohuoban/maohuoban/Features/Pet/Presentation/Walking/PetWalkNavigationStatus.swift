import SwiftUI
import MaohuobanDesignSystem

// PetWalkNavigationStatus 遛弯导航栏状态
// 核心职责：
// - 在地图浮动控制区域展示当前记录状态
// - 展示 GPS 和权限状态提示
struct PetWalkNavigationStatus: View {
    let phase: PetWalkSessionPhase
    let gpsStatusText: String

    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(MHBTheme.Typography.caption.weight(.bold))
                .foregroundStyle(titleColor)
            Label(gpsStatusText, systemImage: "location.fill")
                .font(MHBTheme.Typography.footnote)
                .foregroundStyle(statusColor)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
    }

    private var title: LocalizedStringResource {
        switch phase {
        case .ready:
            "准备记录路线"
        case .tracking:
            "正在记录路线"
        case .paused:
            "已暂停记录"
        case .finished:
            "本次遛弯已结束"
        }
    }

    private var titleColor: Color {
        switch phase {
        case .paused:
            MHBTheme.ColorToken.warning.color
        case .finished:
            MHBTheme.ColorToken.success.color
        case .ready, .tracking:
            MHBTheme.ColorToken.labelPrimary.color
        }
    }

    private var statusColor: Color {
        switch phase {
        case .tracking:
            MHBTheme.ColorToken.success.color
        case .paused:
            MHBTheme.ColorToken.warning.color
        case .ready, .finished:
            MHBTheme.ColorToken.labelSecondary.color
        }
    }
}

// PetWalkUnavailablePanel 遛弯不可用提示
// 核心职责：
// - 在未选择宠物时阻止开始遛弯
// - 保持页面仍可通过系统导航返回
struct PetWalkUnavailablePanel: View {
    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s3) {
            Image(systemName: "pawprint.circle")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
            Text("未选择宠物")
                .font(MHBTheme.Typography.headline)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
            Text("请先创建或选择一只宠物")
                .font(MHBTheme.Typography.caption)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
        }
        .padding(MHBTheme.Spacing.s6)
        .glassEffect(.regular, in: .rect(cornerRadius: MHBTheme.Radius.extraLarge))
        .padding(.horizontal, MHBTheme.Spacing.s6)
    }
}
