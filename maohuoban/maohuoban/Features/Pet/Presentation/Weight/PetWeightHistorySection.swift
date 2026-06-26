import SwiftUI
import MaohuobanDesignSystem

// Internal: extracted from PetWeightDetailScreen

// PetWeightHistorySection 近期体重记录
// 核心职责：
// - 展示最近几条体重记录
// - 提供完整历史入口占位
struct PetWeightHistorySection: View {
    let records: [PetWeightRecord]
    let onOpenRecord: (PetWeightRecord) -> Void
    let onOpenHistory: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
            Text("近期记录")
                .font(MHBTheme.Typography.headline.weight(.semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

            VStack(spacing: 0) {
                ForEach(records) { record in
                    Button {
                        onOpenRecord(record)
                    } label: {
                        PetWeightHistoryRow(record: record)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("pet.weightDetail.recentRecord.\(record.id)")

                    if record.id != records.last?.id {
                        Rectangle()
                            .fill(MHBTheme.ColorToken.separatorSoft.color)
                            .frame(height: 1)
                    }
                }

                Button {
                    onOpenHistory()
                } label: {
                    HStack(spacing: MHBTheme.Spacing.s1) {
                        Text("查看完整历史数据")
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, MHBTheme.Spacing.s4)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, MHBTheme.Spacing.s4)
            .background(MHBTheme.ColorToken.cardSolid.color)
            .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
            .shadow(color: MHBTheme.ColorToken.labelPrimary.color.opacity(0.03), radius: 16, y: 4)
        }
    }
}

// PetWeightHistoryRow 体重历史记录行
// 核心职责：
// - 展示单次体重记录日期、备注、数值和变化
struct PetWeightHistoryRow: View {
    let record: PetWeightRecord

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

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.2f kg", record.weight))
                    .font(MHBTheme.Typography.callout.weight(.semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

                Text(record.deltaText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(record.deltaKind.color)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
        }
        .padding(.vertical, MHBTheme.Spacing.s4)
        .contentShape(Rectangle())
    }
}
