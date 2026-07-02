import SwiftUI
import MaohuobanDesignSystem

// PetWalkHistoryRecordsSection 遛弯记录列表区
// 核心职责：
// - 按周分组展示遛弯记录
// - 在无记录时展示空态
struct PetWalkHistoryRecordsSection: View {
    let sections: [PetWalkHistorySection]
    let onSelectRecord: (PetWalkHistoryRecord) -> Void

    var body: some View {
        if sections.isEmpty {
            PetWalkHistoryEmptyState()
        } else {
            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s4) {
                ForEach(sections) { section in
                    PetWalkHistoryWeekSection(
                        title: section.title,
                        records: section.records,
                        onSelectRecord: onSelectRecord
                    )
                }
            }
        }
    }
}

// PetWalkHistoryWeekSection 遛弯记录周分组
// 核心职责：
// - 展示周分组标题
// - 纵向排列当前分组内记录卡片
private struct PetWalkHistoryWeekSection: View {
    let title: String
    let records: [PetWalkHistoryRecord]
    let onSelectRecord: (PetWalkHistoryRecord) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
            Text(title)
                .font(MHBTheme.Typography.body.weight(.bold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .padding(.leading, MHBTheme.Spacing.s1)

            ForEach(records) { record in
                Button {
                    onSelectRecord(record)
                } label: {
                    PetWalkHistoryRecordCard(record: record)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("pet.walkHistory.recordButton.\(record.id)")
            }
        }
    }
}

// PetWalkHistoryRecordCard 遛弯记录卡片
// 核心职责：
// - 展示单次遛弯时间、里程、时长和热量
// - 展示路线缩略图
private struct PetWalkHistoryRecordCard: View {
    let record: PetWalkHistoryRecord

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s4) {
            PetWalkHistoryMiniRouteMap(routePreview: record.routePreview)

            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(record.dateText)
                            .font(MHBTheme.Typography.body.weight(.bold))
                            .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

                        Text(record.timeRangeText)
                            .font(MHBTheme.Typography.caption.weight(.semibold))
                            .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    }

                    Spacer(minLength: MHBTheme.Spacing.s3)

                    HStack(alignment: .lastTextBaseline, spacing: 2) {
                        Text(record.distanceText)
                            .font(MHBTheme.Typography.title.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(MHBTheme.ColorToken.primary.color)

                        Text("km")
                            .font(MHBTheme.Typography.section.weight(.bold))
                            .foregroundStyle(MHBTheme.ColorToken.labelQuaternary.color)
                    }
                }

                HStack(spacing: MHBTheme.Spacing.s4) {
                    PetWalkHistoryMetricLabel(systemImage: "clock", text: record.durationText)
                    PetWalkHistoryMetricLabel(systemImage: "flame.fill", text: record.caloriesText)
                }
            }
        }
        .padding(MHBTheme.Spacing.s4)
        .background {
            RoundedRectangle(cornerRadius: MHBTheme.Radius.extraLarge, style: .continuous)
                .fill(MHBTheme.ColorToken.cardSolid.color)
        }
        .overlay {
            RoundedRectangle(cornerRadius: MHBTheme.Radius.extraLarge, style: .continuous)
                .stroke(MHBTheme.ColorToken.separator.color, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.02), radius: 12, x: 0, y: 2)
    }
}

// PetWalkHistoryMetricLabel 遛弯记录指标标签
// 核心职责：
// - 展示卡片中的时长与热量
// - 保持图标和文字的弱强调样式
private struct PetWalkHistoryMetricLabel: View {
    let systemImage: String
    let text: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(MHBTheme.Typography.caption.weight(.semibold))
            .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
            .labelStyle(.titleAndIcon)
    }
}

// PetWalkHistoryMiniRouteMap 遛弯记录迷你路线图
// 核心职责：
// - 展示单次遛弯的极简路线缩略图
// - 使用稳定网格背景保持地图语义
private struct PetWalkHistoryMiniRouteMap: View {
    let routePreview: PetWalkHistoryRoutePreview

    var body: some View {
        ZStack {
            PetWalkHistoryMapGrid()

            routePath
                .stroke(
                    MHBTheme.ColorToken.primary.color,
                    style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                )
                .padding(MHBTheme.Spacing.s4)
        }
        .frame(width: 80, height: 80)
        .background {
            RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous)
                .fill(MHBTheme.ColorToken.primaryBackgroundSoft.color)
        }
        .clipShape(.rect(cornerRadius: MHBTheme.Radius.medium))
    }

    private var routePath: Path {
        var path = Path()
        switch routePreview {
        case .arc:
            path.move(to: CGPoint(x: 0, y: 48))
            path.addQuadCurve(to: CGPoint(x: 48, y: 28), control: CGPoint(x: 16, y: 4))
        case .loop:
            path.move(to: CGPoint(x: 0, y: 10))
            path.addQuadCurve(to: CGPoint(x: 32, y: 48), control: CGPoint(x: 42, y: 0))
            path.addQuadCurve(to: CGPoint(x: 48, y: 58), control: CGPoint(x: 42, y: 58))
        case .curve:
            path.move(to: CGPoint(x: 48, y: 0))
            path.addQuadCurve(to: CGPoint(x: 0, y: 48), control: CGPoint(x: -6, y: 20))
        }
        return path
    }
}

// PetWalkHistoryMapGrid 遛弯记录迷你地图网格
// 核心职责：
// - 绘制路线缩略图的浅色地图网格
// - 避免缩略区域成为纯色占位
private struct PetWalkHistoryMapGrid: View {
    var body: some View {
        ZStack {
            ForEach(0..<5, id: \.self) { index in
                Rectangle()
                    .fill(MHBTheme.ColorToken.separator.color)
                    .frame(width: 1)
                    .offset(x: CGFloat(index - 2) * 20)

                Rectangle()
                    .fill(MHBTheme.ColorToken.separator.color)
                    .frame(height: 1)
                    .offset(y: CGFloat(index - 2) * 20)
            }
        }
        .opacity(0.7)
    }
}

// PetWalkHistoryEmptyState 遛弯记录空态
// 核心职责：
// - 在当前宠物或月份无记录时提供明确反馈
// - 保持列表区域高度稳定
private struct PetWalkHistoryEmptyState: View {
    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s3) {
            Image(systemName: "figure.walk.circle")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)

            Text("本月暂无遛弯记录")
                .font(MHBTheme.Typography.headline)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

            Text("完成一次遛弯后会显示在这里")
                .font(MHBTheme.Typography.caption)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, MHBTheme.Spacing.s8)
        .background {
            RoundedRectangle(cornerRadius: MHBTheme.Radius.extraLarge, style: .continuous)
                .fill(MHBTheme.ColorToken.cardSolid.color)
        }
    }
}
