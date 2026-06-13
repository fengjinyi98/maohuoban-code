import SwiftUI
import MaohuobanDesignSystem

// MerchantLitterDetailScreen 商家窝次详情页
// 核心职责：
// - 展示窝次基础信息、父母、同窝幼宠、关系边和近期事件
// - 通过 MerchantLitterDetailStore 加载认证商家窝次追溯详情
struct MerchantLitterDetailScreen: View {
    let merchantID: String
    let litterID: String
    let currentUserID: String?

    @State private var store = MerchantLitterDetailStore()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s4) {
                switch store.phase {
                case .idle, .loading:
                    MerchantLitterDetailLoadingSection()
                case .loaded(let detail):
                    MerchantLitterDetailLoadedView(detail: detail)
                case .failed(let message):
                    MerchantLitterDetailFailedSection(message: message)
                }
            }
            .padding(MHBTheme.Spacing.s4)
        }
        .frame(maxWidth: .infinity)
        .background(MHBTheme.ColorToken.background.color)
        .navigationTitle("窝次详情")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: taskID) {
            await store.load(
                merchantID: merchantID,
                litterID: litterID,
                currentUserID: currentUserID
            )
        }
        .accessibilityIdentifier("merchant.litterDetail.screen")
    }

    private var taskID: String {
        "\(merchantID)-\(litterID)-\(currentUserID ?? "anonymous")"
    }
}

// MerchantLitterDetailLoadedView 商家窝次详情成功态
// 核心职责：
// - 组合窝次详情各业务 section
// - 保持父视图只承担状态分发
private struct MerchantLitterDetailLoadedView: View {
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
private struct MerchantLitterDetailLoadingSection: View {
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
private struct MerchantLitterDetailFailedSection: View {
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

// MerchantLitterDetailHeaderSection 商家窝次摘要模块
// 核心职责：
// - 展示窝次名称、出生日期和状态
// - 呈现出生、成活、可售数量
private struct MerchantLitterDetailHeaderSection: View {
    let detail: MerchantLitterDetail

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s4) {
            HStack(alignment: .top, spacing: MHBTheme.Spacing.s3) {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .font(.system(size: MHBTheme.IconSize.large, weight: .semibold))
                    .foregroundStyle(MHBTheme.ColorToken.primary.color)
                    .frame(width: MHBTheme.IconSize.avatar, height: MHBTheme.IconSize.avatar)
                    .background(MHBTheme.ColorToken.primaryBackground.color)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
                    Text(detail.name)
                        .font(MHBTheme.Typography.title)
                        .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                    Text("\(String(localized: detail.species.displayTitle)) · \(detail.bornAt) 出生")
                        .font(MHBTheme.Typography.callout)
                        .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    Text(detail.status.displayTitle)
                        .font(MHBTheme.Typography.caption)
                        .foregroundStyle(MHBTheme.ColorToken.primary.color)
                        .padding(.horizontal, MHBTheme.Spacing.s2)
                        .padding(.vertical, MHBTheme.Spacing.s1)
                        .background(MHBTheme.ColorToken.primaryBackground.color)
                        .clipShape(Capsule())
                }
            }

            HStack(spacing: MHBTheme.Spacing.s3) {
                MerchantLitterCountCell(title: "出生", value: "\(detail.bornCount)")
                MerchantLitterCountCell(title: "成活", value: "\(detail.aliveCount)")
                MerchantLitterCountCell(title: "可售", value: "\(detail.availableCount)")
            }
        }
        .padding(MHBTheme.Spacing.s4)
        .background(MHBTheme.ColorToken.card.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous)
                .stroke(MHBTheme.ColorToken.cardBorder.color, lineWidth: 0.5)
        )
        .accessibilityIdentifier("merchant.litterDetail.header")
    }
}

// MerchantLitterCountCell 窝次数量单元
// 核心职责：
// - 展示窝次关键数量
// - 保持统计信息尺寸稳定
private struct MerchantLitterCountCell: View {
    let title: LocalizedStringResource
    let value: String

    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s1) {
            Text(value)
                .font(MHBTheme.Typography.title)
                .foregroundStyle(MHBTheme.ColorToken.primary.color)
            Text(title)
                .font(MHBTheme.Typography.caption)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, MHBTheme.Spacing.s3)
        .background(MHBTheme.ColorToken.primaryBackgroundSoft.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
    }
}

// MerchantLitterParentsSection 窝次父母模块
// 核心职责：
// - 展示父母宠物摘要
// - 明确商家追溯的血缘起点
private struct MerchantLitterParentsSection: View {
    let sirePet: MerchantManagedPet?
    let damPet: MerchantManagedPet?

    var body: some View {
        MerchantLitterSectionCard(title: "父母关系") {
            VStack(spacing: MHBTheme.Spacing.s3) {
                MerchantLitterPetRow(roleTitle: "父亲", pet: sirePet)
                MerchantLitterPetRow(roleTitle: "母亲", pet: damPet)
            }
        }
    }
}

// MerchantLitterChildrenSection 同窝幼宠模块
// 核心职责：
// - 展示同窝幼宠列表
// - 呈现每只幼宠当前经营状态
private struct MerchantLitterChildrenSection: View {
    let children: [MerchantManagedPet]

    var body: some View {
        MerchantLitterSectionCard(title: "同窝幼宠") {
            if children.isEmpty {
                MerchantLitterEmptyText(text: "暂无同窝幼宠记录")
            } else {
                VStack(spacing: MHBTheme.Spacing.s3) {
                    ForEach(children) { pet in
                        MerchantLitterPetRow(roleTitle: pet.managedStatus.displayTitle, pet: pet)
                    }
                }
            }
        }
    }
}

// MerchantLitterEventsSection 窝次近期事件模块
// 核心职责：
// - 展示窝次最近关键事件
// - 让商家记录自然沉淀为买家可见时间线
private struct MerchantLitterEventsSection: View {
    let events: [MerchantPetEventRecord]

    var body: some View {
        MerchantLitterSectionCard(title: "近期事件") {
            if events.isEmpty {
                MerchantLitterEmptyText(text: "暂无窝次事件")
            } else {
                VStack(spacing: MHBTheme.Spacing.s3) {
                    ForEach(events) { event in
                        MerchantLitterEventRow(event: event)
                    }
                }
            }
        }
    }
}

// MerchantLitterRelationshipsSection 窝次关系边模块
// 核心职责：
// - 展示系统当前已记录的关系边
// - 为后续图谱化血缘树保留清晰入口
private struct MerchantLitterRelationshipsSection: View {
    let relationships: [MerchantPetRelationship]

    var body: some View {
        MerchantLitterSectionCard(title: "关系追溯") {
            if relationships.isEmpty {
                MerchantLitterEmptyText(text: "暂无关系记录")
            } else {
                VStack(spacing: MHBTheme.Spacing.s3) {
                    ForEach(relationships) { relationship in
                        MerchantLitterRelationshipRow(relationship: relationship)
                    }
                }
            }
        }
    }
}

// MerchantLitterSectionCard 窝次详情分组容器
// 核心职责：
// - 统一窝次详情分组标题和卡片样式
// - 复用 DesignSystem token 控制视觉一致性
private struct MerchantLitterSectionCard<Content: View>: View {
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
private struct MerchantLitterPetRow: View {
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
private struct MerchantLitterEventRow: View {
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
private struct MerchantLitterRelationshipRow: View {
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
private struct MerchantLitterEmptyText: View {
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
