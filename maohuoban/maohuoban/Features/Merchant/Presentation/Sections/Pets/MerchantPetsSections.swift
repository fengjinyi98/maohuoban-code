import SwiftUI
import MaohuobanDesignSystem

// MerchantPetsLoadingSection 商家宠物加载态
// 核心职责：
// - 展示商家宠物列表加载中的稳定骨架
// - 保持页面首次进入时布局不跳变
struct MerchantPetsLoadingSection: View {
    let status: MerchantPetStatus

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s4) {
            MerchantPetsSummaryCard(
                title: status.sectionTitle,
                subtitle: "正在读取商家工作台数据",
                countText: nil
            )

            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(MHBTheme.Spacing.s6)
                .background(MHBTheme.ColorToken.card.color)
                .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
        }
    }
}

// MerchantPetsLoadedSection 商家宠物成功态
// 核心职责：
// - 展示商家宠物列表和空列表状态
// - 将单行渲染拆给 MerchantManagedPetRow
struct MerchantPetsLoadedSection: View {
    let list: MerchantPetList

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s4) {
            MerchantPetsSummaryCard(
                title: list.status.sectionTitle,
                subtitle: "按商家工作台状态筛选",
                countText: "\(list.pets.count)"
            )

            if list.pets.isEmpty {
                MerchantPetsEmptySection(status: list.status)
            } else {
                VStack(spacing: MHBTheme.Spacing.s3) {
                    ForEach(list.pets) { pet in
                        MerchantManagedPetRow(pet: pet)
                    }
                }
            }
        }
    }
}

// MerchantPetsFailedSection 商家宠物失败态
// 核心职责：
// - 展示加载失败原因
// - 保持错误反馈在页面内容区内呈现
struct MerchantPetsFailedSection: View {
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: MHBTheme.IconSize.large, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.warning.color)

            Text("暂时无法加载商家宠物")
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
        .accessibilityIdentifier("merchant.pets.failed")
    }
}

// MerchantPetsSummaryCard 商家宠物列表摘要卡
// 核心职责：
// - 展示当前筛选状态和宠物数量
// - 稳定列表页顶部信息层级
struct MerchantPetsSummaryCard: View {
    let title: LocalizedStringResource
    let subtitle: LocalizedStringResource
    let countText: String?

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s4) {
            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
                Text(title)
                    .font(MHBTheme.Typography.title)
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

                Text(subtitle)
                    .font(MHBTheme.Typography.callout)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
            }

            Spacer()

            if let countText {
                VStack(spacing: MHBTheme.Spacing.s1) {
                    Text(countText)
                        .font(MHBTheme.Typography.largeTitle)
                        .foregroundStyle(MHBTheme.ColorToken.primary.color)
                    Text("只")
                        .font(MHBTheme.Typography.caption)
                        .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                }
                .frame(minWidth: MHBTheme.Spacing.s8)
            }
        }
        .padding(MHBTheme.Spacing.s4)
        .background(MHBTheme.ColorToken.card.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous)
                .stroke(MHBTheme.ColorToken.cardBorder.color, lineWidth: 0.5)
        )
    }
}

// MerchantPetsEmptySection 商家宠物空态
// 核心职责：
// - 展示当前状态下暂无宠物的结果
// - 引导商家回到工作台补充宠物或记录
struct MerchantPetsEmptySection: View {
    let status: MerchantPetStatus

    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s3) {
            Image(systemName: "pawprint")
                .font(.system(size: MHBTheme.IconSize.large, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.primary.color)
                .frame(width: MHBTheme.IconSize.avatar, height: MHBTheme.IconSize.avatar)
                .background(MHBTheme.ColorToken.primaryBackground.color)
                .clipShape(Circle())

            Text("暂无\(String(localized: status.displayTitle))宠物")
                .font(MHBTheme.Typography.headline)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

            Text("新的记录会从商家工作台同步到这里")
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
        }
        .frame(maxWidth: .infinity)
        .padding(MHBTheme.Spacing.s6)
        .background(MHBTheme.ColorToken.card.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
        .accessibilityIdentifier("merchant.pets.empty")
    }
}
