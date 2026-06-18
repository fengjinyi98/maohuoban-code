import SwiftUI
import MaohuobanDesignSystem

// MerchantLitterSectionCard 窝次详情分组容器
// 核心职责：
// - 统一窝次详情分组标题和卡片样式
// - 复用 DesignSystem token 控制视觉一致性
struct MerchantLitterSectionCard<Content: View>: View {
    let title: LocalizedStringResource
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
            Text(title)
                .font(MHBTheme.Typography.headline)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(MHBTheme.Spacing.s4)
        .background(MHBTheme.ColorToken.card.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
    }
}

// MerchantLitterPetRow 窝次宠物摘要行
// 核心职责：
// - 展示父母或幼宠的最小档案
// - 保持关系角色和宠物信息并列呈现
struct MerchantLitterPetRow: View {
    let roleTitle: LocalizedStringResource
    let pet: MerchantManagedPet?

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s3) {
            Text(roleTitle)
                .font(MHBTheme.Typography.caption)
                .foregroundStyle(MHBTheme.ColorToken.primary.color)
                .frame(width: MHBTheme.Spacing.s8 + MHBTheme.Spacing.s4, alignment: .leading)

            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
                Text(pet?.name ?? "待补充")
                    .font(MHBTheme.Typography.callout)
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                Text(petSubtitle)
                    .font(MHBTheme.Typography.caption)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
            }

            Spacer(minLength: MHBTheme.Spacing.s2)
        }
        .padding(MHBTheme.Spacing.s3)
        .background(MHBTheme.ColorToken.cardSolid.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
    }

    private var petSubtitle: String {
        guard let pet else {
            return "血缘记录待完善"
        }
        let breedText: String
        if let breed = pet.breed, !breed.isEmpty {
            breedText = breed
        } else {
            breedText = String(localized: pet.species.displayTitle)
        }
        return "\(breedText) · \(String(localized: pet.sex.displayTitle)) · \(String(localized: pet.sourceKind.displayTitle))"
    }
}

// MerchantLitterEventRow 窝次事件行
// 核心职责：
// - 展示事件标题、摘要和发生时间
// - 保留事件类型与可见范围线索
struct MerchantLitterEventRow: View {
    let event: MerchantPetEventRecord

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
            Text(event.title)
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
            if let summary = event.summary, !summary.isEmpty {
                Text(summary)
                    .font(MHBTheme.Typography.caption)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
            }
            Text("\(event.occurredAt) · 第 \(event.recordRevision) 版")
                .font(MHBTheme.Typography.caption)
                .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(MHBTheme.Spacing.s3)
        .background(MHBTheme.ColorToken.cardSolid.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
    }
}

// MerchantLitterRelationshipRow 窝次关系行
// 核心职责：
// - 展示单条关系边类型和来源
// - 为后续证据快照详情提供基础信息
struct MerchantLitterRelationshipRow: View {
    let relationship: MerchantPetRelationship

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s3) {
            Image(systemName: "link")
                .font(.system(size: MHBTheme.IconSize.small, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.primary.color)
            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
                Text(relationship.relationshipKind.displayTitle)
                    .font(MHBTheme.Typography.callout)
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                Text("\(String(localized: relationship.sourceKind.displayTitle)) · \(relationship.createdAt)")
                    .font(MHBTheme.Typography.caption)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
            }
            Spacer(minLength: MHBTheme.Spacing.s2)
        }
        .padding(MHBTheme.Spacing.s3)
        .background(MHBTheme.ColorToken.cardSolid.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
    }
}

// MerchantLitterEmptyText 窝次详情空文案
// 核心职责：
// - 展示分组内无数据状态
// - 统一空态文本样式
struct MerchantLitterEmptyText: View {
    let text: LocalizedStringResource

    var body: some View {
        Text(text)
            .font(MHBTheme.Typography.callout)
            .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(MHBTheme.Spacing.s3)
            .background(MHBTheme.ColorToken.cardSolid.color)
            .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
    }
}
