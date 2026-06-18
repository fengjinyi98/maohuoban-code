import SwiftUI
import MaohuobanDesignSystem

// MerchantLitterDetailLoadedView 商家窝次详情成功态
// 核心职责：
// - 组合窝次详情各业务 section
// - 保持父视图只承担状态分发
struct MerchantLitterDetailLoadedView: View {
    let detail: MerchantLitterDetail

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s4) {
            MerchantLitterDetailHeaderSection(detail: detail)
            MerchantLitterParentsSection(sirePet: detail.sirePet, damPet: detail.damPet)
            MerchantLitterChildrenSection(children: detail.children)
            MerchantLitterEventsSection(events: detail.recentEvents)
            MerchantLitterRelationshipsSection(relationships: detail.relationships)
        }
    }
}

// MerchantLitterDetailLoadingSection 商家窝次详情加载态
// 核心职责：
// - 展示窝次详情加载过程
// - 稳定首屏布局和可访问标识
struct MerchantLitterDetailLoadingSection: View {
    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s4) {
            ProgressView()
            Text("正在加载窝次详情")
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
        }
        .frame(maxWidth: .infinity)
        .padding(MHBTheme.Spacing.s6)
        .background(MHBTheme.ColorToken.card.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
        .accessibilityIdentifier("merchant.litterDetail.loading")
    }
}

// MerchantLitterDetailFailedSection 商家窝次详情失败态
// 核心职责：
// - 展示加载失败原因
// - 保持错误反馈在页面内容区内呈现
struct MerchantLitterDetailFailedSection: View {
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: MHBTheme.IconSize.large, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.warning.color)
            Text("暂时无法加载窝次详情")
                .font(MHBTheme.Typography.headline)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
            Text(message)
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(MHBTheme.Spacing.s4)
        .background(MHBTheme.ColorToken.card.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
        .accessibilityIdentifier("merchant.litterDetail.failed")
    }
}
