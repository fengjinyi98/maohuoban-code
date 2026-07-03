import SwiftUI
import MaohuobanDesignSystem

// Internal: extracted from PetWeightDetailScreen

// PetWeightRange 体重趋势周期
// 核心职责：
// - 定义体重趋势图的可选时间范围
// - 为周期切换控件提供稳定展示文案
enum PetWeightRange: String, CaseIterable, Hashable {
    case week
    case month
    case sixMonths
    case year

    var title: String {
        switch self {
        case .week: "1周"
        case .month: "1个月"
        case .sixMonths: "6个月"
        case .year: "1年"
        }
    }
}

// PetWeightChartCard 体重趋势图卡片
// 核心职责：
// - 承载周期切换和折线趋势图
// - 将图表和轴标签组合为独立卡片
struct PetWeightChartCard: View {
    @Binding var selectedRange: PetWeightRange
    let records: [PetWeightRecord]

    private var presentation: PetWeightChartPresentation {
        PetWeightChartPresentation(records: records, selectedRange: selectedRange)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s4) {
            PetWeightRangePicker(selectedRange: $selectedRange)

            PetWeightLineChart(records: presentation.records)
                .frame(height: 172)

            HStack {
                ForEach(presentation.records.reversed()) { record in
                    Text(record.monthText)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.leading, MHBTheme.Spacing.s6)
        }
        .padding(MHBTheme.Spacing.s4)
        .background(MHBTheme.ColorToken.cardSolid.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
        .shadow(color: MHBTheme.ColorToken.labelPrimary.color.opacity(0.03), radius: 16, y: 4)
    }
}

// PetWeightRangePicker 周期切换控件
// 核心职责：
// - 展示体重趋势的时间范围
// - 维护轻量选中状态
struct PetWeightRangePicker: View {
    @Binding var selectedRange: PetWeightRange

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s5) {
            ForEach(PetWeightRange.allCases, id: \.self) { range in
                Button {
                    selectedRange = range
                } label: {
                    VStack(spacing: MHBTheme.Spacing.s1) {
                        Text(range.title)
                            .font(.system(size: 13, weight: selectedRange == range ? .semibold : .regular))
                            .foregroundStyle(
                                selectedRange == range
                                    ? MHBTheme.ColorToken.labelPrimary.color
                                    : MHBTheme.ColorToken.labelSecondary.color
                            )

                        Capsule()
                            .fill(
                                selectedRange == range
                                    ? MHBTheme.ColorToken.labelPrimary.color
                                    : Color.clear
                            )
                            .frame(width: 12, height: 3)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.bottom, MHBTheme.Spacing.s1)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(MHBTheme.ColorToken.separatorSoft.color)
                .frame(height: 1)
        }
    }
}
