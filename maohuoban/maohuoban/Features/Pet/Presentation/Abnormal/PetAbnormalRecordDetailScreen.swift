import SwiftUI
import MaohuobanDesignSystem

// PetAbnormalRecordDetailScreen 异常记录详情页
// 核心职责：
// - 展示单条异常记录的宠物、异常项、程度、备注和照片
// - 聚合异常事件下的后续用户记录和关联记录
// - 不展示 AI/LLM 建议，避免主动记录详情与智能建议混淆
struct PetAbnormalRecordDetailScreen: View {
    let recordID: String

    @State private var presentedSheet: PetAbnormalRecordDetailSheet?

    private var presentation: PetAbnormalRecordDetailPresentation {
        PetAbnormalRecordDetailPresentation.mock(recordID: recordID)
    }

    var body: some View {
        MHBScreenScrollView {
            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s5) {
                PetAbnormalRecordDetailHeader(presentation: presentation)
                PetAbnormalRecordSymptomSection(presentation: presentation)
                PetAbnormalRecordObservationSection(observations: presentation.observations)
                PetAbnormalRecordEvidenceSection(
                    note: presentation.note,
                    photoAssetNames: presentation.photoAssetNames
                )
                PetAbnormalRecordProgressSection(
                    records: presentation.relatedRecords,
                    onOpenRecord: { record in
                        presentedSheet = .relatedRecord(record)
                    }
                )
                PetAbnormalRecordEpisodeActions(
                    onSelectAction: { action in
                        presentedSheet = .action(action)
                    }
                )
                PetAbnormalRecordDetailActions()
            }
            .padding(.horizontal, MHBTheme.Spacing.s5)
            .padding(.top, MHBTheme.Spacing.s6)
            .padding(.bottom, MHBTheme.Spacing.s8)
        }
        .frame(maxWidth: .infinity)
        .background(MHBTheme.ColorToken.background.color)
        .navigationTitle("异常详情")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .action(let action):
                PetAbnormalRecordActionSheet(action: action)
            case .relatedRecord(let record):
                PetAbnormalRecordRelatedRecordSheet(record: record)
            }
        }
        .accessibilityIdentifier("pet.abnormalRecordDetail.screen")
    }
}

// PetAbnormalRecordDetailHeader 异常详情头部
// 核心职责：
// - 展示异常记录标题、宠物头像名称和发生时间
// - 突出异常程度，便于用户快速回看风险等级
private struct PetAbnormalRecordDetailHeader: View {
    let presentation: PetAbnormalRecordDetailPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s4) {
            HStack(spacing: MHBTheme.Spacing.s4) {
                Image(systemName: "cross.case.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(presentation.tint)
                    .frame(width: 56, height: 56)
                    .background(presentation.tint.opacity(0.10))
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

            HStack(alignment: .center, spacing: MHBTheme.Spacing.s3) {
                Text(presentation.severityText)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(presentation.tint)
                    .padding(.horizontal, MHBTheme.Spacing.s3)
                    .padding(.vertical, MHBTheme.Spacing.s2)
                    .background(presentation.tint.opacity(0.12), in: Capsule())

                Text(presentation.severityDescription)
                    .font(MHBTheme.Typography.callout)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
            }
        }
        .padding(.vertical, MHBTheme.Spacing.s4)
    }
}

// PetAbnormalRecordSymptomSection 异常项分组
// 核心职责：
// - 展示本次记录涉及的异常类型
// - 使用图标标签帮助用户快速识别异常范围
private struct PetAbnormalRecordSymptomSection: View {
    let presentation: PetAbnormalRecordDetailPresentation

    var body: some View {
        PetAbnormalRecordDetailSection(title: "异常项") {
            MHBFlowLayout(
                horizontalSpacing: MHBTheme.Spacing.s2,
                verticalSpacing: MHBTheme.Spacing.s2
            ) {
                ForEach(presentation.symptoms) { symptom in
                    Label(symptom.title, systemImage: symptom.systemImage)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(presentation.tint)
                        .padding(.horizontal, MHBTheme.Spacing.s3)
                        .padding(.vertical, MHBTheme.Spacing.s2)
                        .background(presentation.tint.opacity(0.10), in: Capsule())
                }
            }
        }
    }
}

// PetAbnormalRecordObservationSection 具体表现分组
// 核心职责：
// - 展示异常记录里的细分表现
// - 保持键值信息可扫描
private struct PetAbnormalRecordObservationSection: View {
    let observations: [PetAbnormalRecordDetailPresentation.Observation]

    var body: some View {
        PetAbnormalRecordDetailSection(title: "具体表现") {
            VStack(spacing: 0) {
                ForEach(observations) { observation in
                    PetAbnormalRecordInfoRow(
                        title: observation.title,
                        value: observation.value
                    )

                    if observation.id != observations.last?.id {
                        Rectangle()
                            .fill(MHBTheme.ColorToken.separatorSoft.color)
                            .frame(height: 1)
                    }
                }
            }
        }
    }
}

// PetAbnormalRecordEvidenceSection 异常备注与照片分组
// 核心职责：
// - 展示用户补充描述
// - 展示异常记录关联照片
private struct PetAbnormalRecordEvidenceSection: View {
    let note: String
    let photoAssetNames: [String]

    var body: some View {
        PetAbnormalRecordDetailSection(title: "备注与照片") {
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

// PetAbnormalRecordDetailSection 异常详情分组容器
// 核心职责：
// - 统一异常详情分组标题和卡片样式
// - 复用主题 token 保持详情页一致性
struct PetAbnormalRecordDetailSection<Content: View>: View {
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

// PetAbnormalRecordInfoRow 异常详情信息行
// 核心职责：
// - 展示单项异常表现
// - 支持长文本右侧换行展示
private struct PetAbnormalRecordInfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: MHBTheme.Spacing.s4) {
            Text(title)
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)

            Spacer(minLength: MHBTheme.Spacing.s3)

            Text(value)
                .font(MHBTheme.Typography.callout.weight(.semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, MHBTheme.Spacing.s3)
    }
}

// PetAbnormalRecordDetailActions 异常详情底部操作
// 核心职责：
// - 保留后续编辑和删除入口
// - 与其他记录详情底部操作保持一致
private struct PetAbnormalRecordDetailActions: View {
    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s3) {
            Button("修改记录信息") {}
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(MHBTheme.ColorToken.separatorSoft.color, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .buttonStyle(.plain)

            Button(role: .destructive) {} label: {
                Image(systemName: "trash")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(MHBTheme.ColorToken.danger.color)
                    .frame(width: 48, height: 48)
                    .background(MHBTheme.ColorToken.danger.color.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .accessibilityIdentifier("pet.abnormalRecordDetail.actions")
    }
}
