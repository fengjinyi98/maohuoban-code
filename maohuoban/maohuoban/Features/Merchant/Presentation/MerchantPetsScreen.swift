import SwiftUI
import MaohuobanDesignSystem

// MerchantPetsScreen 商家宠物列表页
// 核心职责：
// - 展示指定商家和状态下的在管宠物
// - 通过 MerchantPetsStore 触发列表加载并渲染状态
struct MerchantPetsScreen: View {
    let merchantID: String
    let status: MerchantPetStatus
    let currentUserID: String?

    @State private var store = MerchantPetsStore()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s4) {
                switch store.phase {
                case .idle, .loading:
                    MerchantPetsLoadingSection(status: status)
                case .loaded(let list):
                    MerchantPetsLoadedSection(list: list)
                case .failed(let message):
                    MerchantPetsFailedSection(message: message)
                }
            }
            .padding(MHBTheme.Spacing.s4)
        }
        .frame(maxWidth: .infinity)
        .background(MHBTheme.ColorToken.background.color)
        .navigationTitle(Text(status.sectionTitle))
        .task(id: taskID) {
            await store.load(
                merchantID: merchantID,
                status: status,
                currentUserID: currentUserID
            )
        }
        .accessibilityIdentifier("merchant.pets.screen")
    }

    private var taskID: String {
        "\(merchantID)-\(status.rawValue)-\(currentUserID ?? "anonymous")"
    }
}

// MerchantPetsLoadingSection 商家宠物加载态
// 核心职责：
// - 展示商家宠物列表加载中的稳定骨架
// - 保持页面首次进入时布局不跳变
private struct MerchantPetsLoadingSection: View {
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
private struct MerchantPetsLoadedSection: View {
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
private struct MerchantPetsFailedSection: View {
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
private struct MerchantPetsSummaryCard: View {
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
private struct MerchantPetsEmptySection: View {
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

// MerchantManagedPetRow 商家在管宠物行
// 核心职责：
// - 展示单只商家宠物的档案摘要
// - 呈现来源、状态和更新时间等追溯线索
private struct MerchantManagedPetRow: View {
    let pet: MerchantManagedPet

    var body: some View {
        HStack(alignment: .top, spacing: MHBTheme.Spacing.s3) {
            MerchantPetSpeciesBadge(species: pet.species)

            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
                HStack(alignment: .firstTextBaseline, spacing: MHBTheme.Spacing.s2) {
                    Text(pet.name)
                        .font(MHBTheme.Typography.headline)
                        .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

                    Text(pet.managedStatus.displayTitle)
                        .font(MHBTheme.Typography.caption)
                        .foregroundStyle(MHBTheme.ColorToken.primary.color)
                        .padding(.horizontal, MHBTheme.Spacing.s2)
                        .padding(.vertical, MHBTheme.Spacing.s1)
                        .background(MHBTheme.ColorToken.primaryBackground.color)
                        .clipShape(Capsule())
                }

                Text(petProfileText)
                    .font(MHBTheme.Typography.callout)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)

                Text("来源：\(String(localized: pet.sourceKind.displayTitle))")
                    .font(MHBTheme.Typography.caption)
                    .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)

                Text("更新：\(pet.updatedAt)")
                    .font(MHBTheme.Typography.caption)
                    .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
            }

            Spacer(minLength: MHBTheme.Spacing.s2)
        }
        .padding(MHBTheme.Spacing.s4)
        .background(MHBTheme.ColorToken.card.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous)
                .stroke(MHBTheme.ColorToken.cardBorder.color, lineWidth: 0.5)
        )
        .accessibilityIdentifier("merchant.pets.row.\(pet.id)")
    }

    private var petProfileText: String {
        let breedText: String
        if let breed = pet.breed, !breed.isEmpty {
            breedText = breed
        } else {
            breedText = String(localized: pet.species.displayTitle)
        }

        let birthdayText: String
        if let birthday = pet.birthday, !birthday.isEmpty {
            birthdayText = birthday
        } else {
            birthdayText = "生日待补"
        }

        return "\(breedText) · \(String(localized: pet.sex.displayTitle)) · \(birthdayText)"
    }
}

// MerchantPetSpeciesBadge 商家宠物物种标识
// 核心职责：
// - 使用统一图标表达宠物物种
// - 为列表行提供稳定视觉锚点
private struct MerchantPetSpeciesBadge: View {
    let species: PetSpecies

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: MHBTheme.IconSize.medium, weight: .semibold))
            .foregroundStyle(MHBTheme.ColorToken.primary.color)
            .frame(width: MHBTheme.IconSize.avatar, height: MHBTheme.IconSize.avatar)
            .background(MHBTheme.ColorToken.primaryBackgroundSoft.color)
            .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
    }

    private var systemImage: String {
        switch species {
        case .dog: "dog.fill"
        case .cat: "cat.fill"
        case .other: "pawprint.fill"
        }
    }
}
