import SwiftUI
import MaohuobanDesignSystem

// PetWeightRecordDetailScreen 单条体重记录详情页
// 核心职责：
// - 展示单次体重记录的宠物、体重、变化、标签和备注
// - 与快速事实详情保持小票式详情结构
// - 区分体重总览页和单条记录详情页的产品边界
struct PetWeightRecordDetailScreen: View {
    let recordID: String

    private var presentation: PetWeightRecordDetailPresentation {
        PetWeightRecordDetailPresentation.mock(recordID: recordID)
    }

    var body: some View {
        MHBScreenScrollView {
            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s5) {
                PetWeightRecordReceiptCard(presentation: presentation)
                PetWeightRecordNearbySection(records: presentation.nearbyRecords)
                PetWeightRecordDetailActions()
            }
            .padding(.horizontal, MHBTheme.Spacing.s5)
            .padding(.top, MHBTheme.Spacing.s6)
            .padding(.bottom, MHBTheme.Spacing.s8)
        }
        .frame(maxWidth: .infinity)
        .background(MHBTheme.ColorToken.background.color)
        .navigationTitle("体重记录详情")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("pet.weightRecordDetail.screen")
    }
}

// PetWeightRecordReceiptCard 体重记录小票卡片
// 核心职责：
// - 突出展示本次体重数值和变化
// - 展示单条记录的关键字段
private struct PetWeightRecordReceiptCard: View {
    let presentation: PetWeightRecordDetailPresentation

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            Image(systemName: "scalemass.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(presentation.tint)
                .frame(width: 64, height: 64)
                .background(presentation.tint.opacity(0.10))
                .clipShape(Circle())
                .padding(.bottom, MHBTheme.Spacing.s5)

            Text("体重记录")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .multilineTextAlignment(.center)
                .padding(.bottom, MHBTheme.Spacing.s2)

            Text(presentation.timeText)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                .multilineTextAlignment(.center)
                .padding(.bottom, MHBTheme.Spacing.s5)

            HStack(alignment: .firstTextBaseline, spacing: MHBTheme.Spacing.s1) {
                Text(presentation.weightText)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

                Text("kg")
                    .font(MHBTheme.Typography.title.weight(.semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
            }
            .padding(.bottom, MHBTheme.Spacing.s2)

            PetWeightRecordDeltaTag(
                text: presentation.deltaText,
                kind: presentation.deltaKind
            )
            .padding(.bottom, MHBTheme.Spacing.s6)

            PetWeightRecordDashedDivider()
                .padding(.bottom, MHBTheme.Spacing.s5)

            VStack(spacing: 0) {
                ForEach(presentation.rows) { row in
                    PetWeightRecordReceiptRow(row: row)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, MHBTheme.Spacing.s6)
        .padding(.vertical, MHBTheme.Spacing.s8)
        .background(MHBTheme.ColorToken.cardSolid.color)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: MHBTheme.ColorToken.labelPrimary.color.opacity(0.02), radius: 12, y: 4)
        .accessibilityIdentifier("pet.weightRecordDetail.receiptCard")
    }
}

// PetWeightRecordDeltaTag 体重变化标签
// 核心职责：
// - 展示本次记录相对上次的变化
// - 使用趋势颜色帮助用户快速判断方向
private struct PetWeightRecordDeltaTag: View {
    let text: String
    let kind: PetWeightRecordDetailPresentation.DeltaKind

    var body: some View {
        Label(text, systemImage: kind.systemImage)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(kind.color)
            .padding(.horizontal, MHBTheme.Spacing.s3)
            .padding(.vertical, MHBTheme.Spacing.s2)
            .background(kind.color.opacity(0.12), in: Capsule())
    }
}

// PetWeightRecordReceiptRow 体重记录字段行
// 核心职责：
// - 展示体重详情里的单项字段和值
// - 支持宠物头像名称和普通文本两种展示
private struct PetWeightRecordReceiptRow: View {
    let row: PetWeightRecordDetailPresentation.Row

    var body: some View {
        HStack(alignment: .top, spacing: MHBTheme.Spacing.s4) {
            Text(row.title)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)

            Spacer(minLength: MHBTheme.Spacing.s4)

            PetWeightRecordReceiptRowValue(value: row.value)
        }
        .padding(.vertical, MHBTheme.Spacing.s3)
    }
}

// PetWeightRecordReceiptRowValue 体重记录字段值
// 核心职责：
// - 渲染普通文本或宠物身份组合
// - 复用头像基础设施保持记录详情一致
private struct PetWeightRecordReceiptRowValue: View {
    let value: PetWeightRecordDetailPresentation.RowValue

    var body: some View {
        switch value {
        case .text(let text):
            Text(text)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .multilineTextAlignment(.trailing)
        case .pet(let pet):
            HStack(spacing: MHBTheme.Spacing.s2) {
                MHBAvatar(
                    subject: .pet(pet.avatarPet),
                    size: .custom(28),
                    shape: .circle
                )

                Text(pet.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                    .lineLimit(1)
            }
        }
    }
}

// PetWeightRecordNearbySection 体重相邻记录区
// 核心职责：
// - 展示本次记录附近的体重上下文
// - 帮助用户判断单次体重变化是否明显
private struct PetWeightRecordNearbySection: View {
    let records: [PetWeightRecordDetailPresentation.NearbyRecord]

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
            Text("附近记录")
                .font(MHBTheme.Typography.headline.weight(.semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

            VStack(spacing: 0) {
                ForEach(records) { record in
                    PetWeightRecordNearbyRow(record: record)

                    if record.id != records.last?.id {
                        Rectangle()
                            .fill(MHBTheme.ColorToken.separatorSoft.color)
                            .frame(height: 1)
                    }
                }
            }
            .padding(.horizontal, MHBTheme.Spacing.s4)
            .background(MHBTheme.ColorToken.cardSolid.color)
            .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
            .shadow(color: MHBTheme.ColorToken.labelPrimary.color.opacity(0.03), radius: 16, y: 4)
        }
    }
}

// PetWeightRecordNearbyRow 附近体重记录行
// 核心职责：
// - 展示相邻体重记录的日期、标签和数值
// - 标记当前正在查看的记录
private struct PetWeightRecordNearbyRow: View {
    let record: PetWeightRecordDetailPresentation.NearbyRecord

    var body: some View {
        HStack(alignment: .center, spacing: MHBTheme.Spacing.s3) {
            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
                Text(record.dateText)
                    .font(MHBTheme.Typography.callout.weight(.semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

                Text(record.note)
                    .font(MHBTheme.Typography.caption)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
            }

            Spacer(minLength: MHBTheme.Spacing.s3)

            VStack(alignment: .trailing, spacing: MHBTheme.Spacing.s1 / 2) {
                Text(record.weightText)
                    .font(MHBTheme.Typography.callout.weight(.semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

                if record.isCurrent {
                    Text("当前")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(MHBTheme.ColorToken.primary.color)
                }
            }
        }
        .padding(.vertical, MHBTheme.Spacing.s4)
    }
}

// PetWeightRecordDetailActions 体重详情底部操作
// 核心职责：
// - 保留后续编辑和删除入口
// - 与快速事实详情底部操作保持一致
private struct PetWeightRecordDetailActions: View {
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
        .accessibilityIdentifier("pet.weightRecordDetail.actions")
    }
}

// PetWeightRecordDashedDivider 体重记录虚线分隔
// 核心职责：
// - 承载小票样式字段区分隔线
// - 保持单条记录详情的视觉节奏
private struct PetWeightRecordDashedDivider: View {
    var body: some View {
        Line()
            .stroke(
                MHBTheme.ColorToken.separator.color,
                style: StrokeStyle(lineWidth: 1, dash: [5, 5])
            )
            .frame(height: 1)
    }

    private struct Line: Shape {
        nonisolated func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            return path
        }
    }
}
