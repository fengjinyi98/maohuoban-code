
import SwiftUI
import MaohuobanDesignSystem

// PetQuickFactDetailScreen 快速事实详情页
// 核心职责：
// - 只展示便便正常、精神不错、食欲正常三类一次性快速事实
// - 复用宠物头像基础设施展示 mock 宠物身份
// - 保持喂食、异常、体重、医疗照护和遛弯记录不进入此页面
struct PetQuickFactDetailScreen: View {
    let kind: PetQuickFactDetailKind

    var body: some View {
        MHBScreenScrollView {
            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s5) {
                PetQuickFactReceiptCard(
                    presentation: PetQuickFactDetailPresentation(kind: kind)
                )
                PetQuickFactDetailActions()
            }
            .padding(.horizontal, MHBTheme.Spacing.s5)
            .padding(.top, MHBTheme.Spacing.s6)
            .padding(.bottom, MHBTheme.Spacing.s8)
        }
        .frame(maxWidth: .infinity)
        .background(MHBTheme.ColorToken.background.color)
        .navigationTitle("快速事实详情")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("pet.quickFactDetail.screen")
    }
}

// PetQuickFactReceiptCard 快速事实小票卡片
// 核心职责：
// - 展示快速事实图标、标题、发生时间和关键字段
// - 让三类快速事实保持一致的轻量详情结构
private struct PetQuickFactReceiptCard: View {
    let presentation: PetQuickFactDetailPresentation

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            Image(systemName: presentation.systemImage)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(presentation.tint)
                .frame(width: 64, height: 64)
                .background(presentation.tint.opacity(0.10))
                .clipShape(Circle())
                .padding(.bottom, MHBTheme.Spacing.s5)

            Text(presentation.title)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .multilineTextAlignment(.center)
                .padding(.bottom, MHBTheme.Spacing.s2)

            Text(presentation.timeText)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                .multilineTextAlignment(.center)
                .padding(.bottom, MHBTheme.Spacing.s8)

            PetQuickFactDashedDivider()
                .padding(.bottom, MHBTheme.Spacing.s5)

            VStack(spacing: 0) {
                ForEach(presentation.rows) { row in
                    PetQuickFactReceiptRow(row: row)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, MHBTheme.Spacing.s6)
        .padding(.vertical, MHBTheme.Spacing.s8)
        .background(MHBTheme.ColorToken.cardSolid.color)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: MHBTheme.ColorToken.labelPrimary.color.opacity(0.02), radius: 12, y: 4)
        .accessibilityIdentifier("pet.quickFactDetail.receiptCard")
    }
}

// PetQuickFactReceiptRow 快速事实小票字段行
// 核心职责：
// - 展示单个字段和值
// - 支持宠物身份和普通文本两种字段值
private struct PetQuickFactReceiptRow: View {
    let row: PetQuickFactDetailPresentation.Row

    var body: some View {
        HStack(alignment: .top, spacing: MHBTheme.Spacing.s4) {
            Text(row.title)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)

            Spacer(minLength: MHBTheme.Spacing.s4)

            PetQuickFactReceiptRowValue(value: row.value)
        }
        .padding(.vertical, MHBTheme.Spacing.s3)
    }
}

// PetQuickFactReceiptRowValue 快速事实字段值
// 核心职责：
// - 渲染普通文本或宠物头像名称组合
// - 复用 MHBAvatar 保持头像基础设施一致
private struct PetQuickFactReceiptRowValue: View {
    let value: PetQuickFactDetailPresentation.RowValue

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
                    subject: .pet(
                        MHBAvatarPet(
                            id: pet.id,
                            name: pet.name,
                            source: pet.avatarSource,
                            species: .other,
                            sex: .unknown
                        )
                    ),
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

// PetQuickFactDashedDivider 快速事实虚线分隔
// 核心职责：
// - 承载小票样式字段区分隔线
// - 避免引入图片或 UIKit 桥接
private struct PetQuickFactDashedDivider: View {
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

// PetQuickFactDetailActions 快速事实底部操作
// 核心职责：
// - 保留快速事实后续编辑和删除入口
// - 与当前详情页底部操作视觉保持一致
private struct PetQuickFactDetailActions: View {
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
        .accessibilityIdentifier("pet.quickFactDetail.actions")
    }
}

// PetRecordDetailPlaceholderScreen 记录详情占位页
// 核心职责：
// - 为尚未产品化的记录详情类型提供明确目标页
// - 在快速 UI 阶段防止非快速事实误入快速事实详情

