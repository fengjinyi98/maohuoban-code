import SwiftUI
import MaohuobanDesignSystem

// PetFeedingDetailScreen 喂食记录详情页
// 核心职责：
// - 展示单条喂食记录的宠物、份量、食品、备注和照片
// - 使用少量、正常、多一点等低摩擦份量语义
// - 避免展示克数、进食方式和记录来源等当前产品边界外字段
struct PetFeedingDetailScreen: View {
    let recordID: String

    private var presentation: PetFeedingDetailPresentation {
        PetFeedingDetailPresentation.mock(recordID: recordID)
    }

    var body: some View {
        MHBScreenScrollView {
            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s5) {
                PetFeedingDetailHeader(presentation: presentation)
                PetFeedingDataSection(amountText: presentation.amountText)
                PetFeedingFoodSection(food: presentation.food)
                PetFeedingEvidenceSection(
                    note: presentation.note,
                    photoAssetNames: presentation.photoAssetNames
                )
            }
            .padding(.horizontal, MHBTheme.Spacing.s5)
            .padding(.top, MHBTheme.Spacing.s6)
            .padding(.bottom, MHBTheme.Spacing.s8)
        }
        .frame(maxWidth: .infinity)
        .background(MHBTheme.ColorToken.background.color)
        .navigationTitle("喂食详情")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("pet.feedingDetail.screen")
    }
}

// PetFeedingDetailHeader 喂食详情头部
// 核心职责：
// - 展示喂食事件状态、宠物头像名称和发生时间
// - 让用户快速确认记录归属
private struct PetFeedingDetailHeader: View {
    let presentation: PetFeedingDetailPresentation

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s4) {
            Image(systemName: "fork.knife")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Color(mhbHex: "0093DD"))
                .frame(width: 56, height: 56)
                .background(Color(mhbHex: "0093DD").opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))

            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
                Text(presentation.title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

                HStack(spacing: MHBTheme.Spacing.s2) {
                    MHBAvatar(
                        subject: .pet(presentation.pet.avatarPet),
                        size: .custom(24),
                        shape: .circle
                    )

                    Text("\(presentation.pet.name) · \(presentation.timeText)")
                        .font(MHBTheme.Typography.caption)
                        .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: MHBTheme.Spacing.s2)
        }
        .padding(.vertical, MHBTheme.Spacing.s4)
    }
}

// PetFeedingDataSection 喂食数据分组
// 核心职责：
// - 展示低摩擦份量描述
// - 避免使用克数作为主要记录方式
private struct PetFeedingDataSection: View {
    let amountText: String

    var body: some View {
        PetFeedingDetailSection(title: "喂食数据") {
            PetFeedingDetailInfoRow(title: "份量", value: amountText)
        }
    }
}

// PetFeedingFoodSection 关联食品分组
// 核心职责：
// - 展示本次喂食关联的储物柜食品
// - 保留食品图片、名称和规格信息
private struct PetFeedingFoodSection: View {
    let food: PetFeedingDetailPresentation.Food

    var body: some View {
        PetFeedingDetailSection(title: "关联食品") {
            HStack(spacing: MHBTheme.Spacing.s3) {
                PetFeedingFoodThumbnail(assetName: food.assetName)

                VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
                    Text(food.name)
                        .font(MHBTheme.Typography.callout.weight(.semibold))
                        .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                        .lineLimit(1)

                    Text(food.subtitle)
                        .font(MHBTheme.Typography.caption)
                        .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                        .lineLimit(1)
                }

                Spacer(minLength: MHBTheme.Spacing.s2)
            }
        }
    }
}

// PetFeedingEvidenceSection 喂食备注与照片分组
// 核心职责：
// - 展示用户补充备注
// - 展示本次喂食可选照片
private struct PetFeedingEvidenceSection: View {
    let note: String
    let photoAssetNames: [String]

    var body: some View {
        PetFeedingDetailSection(title: "备注与照片") {
            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
                Text(note)
                    .font(MHBTheme.Typography.callout)
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: MHBTheme.Spacing.s2) {
                    ForEach(photoAssetNames, id: \.self) { assetName in
                        Image(assetName)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 86, height: 86)
                            .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
                    }
                }
            }
        }
    }
}

// PetFeedingDetailSection 喂食详情分组容器
// 核心职责：
// - 统一喂食详情分组标题和卡片样式
// - 复用主题 token 保持页面一致性
private struct PetFeedingDetailSection<Content: View>: View {
    let title: LocalizedStringResource
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
            Text(title)
                .font(MHBTheme.Typography.section)
                .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
                .textCase(.uppercase)

            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(MHBTheme.Spacing.s4)
            .background(MHBTheme.ColorToken.cardSolid.color)
            .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.extraLarge, style: .continuous))
            .shadow(color: MHBTheme.ColorToken.labelPrimary.color.opacity(0.02), radius: 10, y: 3)
        }
    }
}

// PetFeedingDetailInfoRow 喂食详情信息行
// 核心职责：
// - 展示单项键值信息
// - 保持左右可扫描布局
private struct PetFeedingDetailInfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s4) {
            Text(title)
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)

            Spacer(minLength: MHBTheme.Spacing.s3)

            Text(value)
                .font(MHBTheme.Typography.callout.weight(.semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
        }
        .frame(minHeight: 44)
    }
}

// PetFeedingFoodThumbnail 喂食食品缩略图
// 核心职责：
// - 展示关联食品图片
// - 提供本地 mock 图片兜底
private struct PetFeedingFoodThumbnail: View {
    let assetName: String

    var body: some View {
        Image(assetName)
            .resizable()
            .scaledToFill()
            .frame(width: 52, height: 52)
            .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
    }
}

// PetFeedingDetailPresentation 喂食详情展示模型
// 核心职责：
// - 提供快速 UI 阶段的喂食详情 mock 数据
// - 约束喂食详情字段只展示当前产品边界内的信息
private struct PetFeedingDetailPresentation {
    struct Pet: Equatable {
        let id: String
        let name: String
        let avatarSource: MHBAvatarSource

        var avatarPet: MHBAvatarPet {
            MHBAvatarPet(
                id: id,
                name: name,
                source: avatarSource,
                species: .other,
                sex: .unknown
            )
        }
    }

    struct Food: Equatable {
        let name: String
        let subtitle: String
        let assetName: String
    }

    let recordID: String
    let title: String
    let pet: Pet
    let timeText: String
    let amountText: String
    let food: Food
    let note: String
    let photoAssetNames: [String]

    static func mock(recordID: String) -> PetFeedingDetailPresentation {
        PetFeedingDetailPresentation(
            recordID: recordID,
            title: "已喂食记录",
            pet: Pet(
                id: "pet-feeding-mock",
                name: "测试名字1",
                avatarSource: .asset("HomePetHeroMock")
            ),
            timeText: "2026-06-25 10:30",
            amountText: "正常",
            food: Food(
                name: "原味六种鱼",
                subtitle: "# 当前主粮 · 5.4kg 大包装",
                assetName: "HomePetFoodBowl"
            ),
            note: "今天食欲很好，主粮吃完得很快。",
            photoAssetNames: ["HomePetFoodBowl"]
        )
    }
}
