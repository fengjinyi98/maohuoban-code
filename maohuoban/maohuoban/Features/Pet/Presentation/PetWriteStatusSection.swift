import SwiftUI
import MaohuobanDesignSystem

// PetWriteStatusSection 宠物写入状态提示
// 核心职责：
// - 展示宠物写入成功或失败反馈
// - 让创建与记录页面复用统一状态样式
struct PetWriteStatusSection: View {
    let phase: PetWritePhase
    let successMessage: String?
    let derivativeMessage: String?

    var body: some View {
        switch phase {
        case .idle, .submitting:
            EmptyView()
        case .createdPet, .recordedEvent, .importedTradePet, .updatedPet, .uploadedAvatar, .uploadedBackground, .deletedPet:
            VStack(spacing: MHBTheme.Spacing.s2) {
                PetWriteStatusBanner(
                    systemImage: "checkmark.circle.fill",
                    title: successMessage ?? "已保存",
                    color: MHBTheme.ColorToken.primary.color
                )
                if let derivativeMessage {
                    PetWriteStatusBanner(
                        systemImage: "sparkles",
                        title: derivativeMessage,
                        color: MHBTheme.ColorToken.teal.color
                    )
                }
            }
        case .failed(let message):
            PetWriteStatusBanner(
                systemImage: "exclamationmark.triangle.fill",
                title: message,
                color: MHBTheme.ColorToken.danger.color
            )
        }
    }
}

// PetWriteStatusBanner 宠物写入状态条
// 核心职责：
// - 承载单条状态反馈内容
// - 使用 DesignSystem token 保持页面视觉一致
private struct PetWriteStatusBanner: View {
    let systemImage: String
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s2) {
            Image(systemName: systemImage)
                .font(.system(size: MHBTheme.IconSize.small, weight: .semibold))
                .foregroundStyle(color)
            Text(title)
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
            Spacer()
        }
        .padding(MHBTheme.Spacing.s3)
        .background(MHBTheme.ColorToken.primaryBackgroundSoft.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
    }
}
