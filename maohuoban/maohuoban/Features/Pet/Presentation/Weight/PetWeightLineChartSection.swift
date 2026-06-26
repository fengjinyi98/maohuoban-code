import SwiftUI
import MaohuobanDesignSystem

// Internal: extracted from PetWeightDetailScreen

// PetWeightLineChart 体重折线图
// 核心职责：
// - 使用本地路径绘制 mock 体重趋势
// - 展示末次记录数值标签
struct PetWeightLineChart: View {
    let records: [PetWeightRecord]

    private var orderedRecords: [PetWeightRecord] {
        Array(records.reversed())
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let plotRect = CGRect(
                x: MHBTheme.Spacing.s6,
                y: MHBTheme.Spacing.s3,
                width: max(size.width - MHBTheme.Spacing.s6, 1),
                height: max(size.height - MHBTheme.Spacing.s6, 1)
            )
            let points = chartPoints(in: plotRect)

            ZStack {
                PetWeightGridLines(plotRect: plotRect)

                if points.count > 1 {
                    PetWeightAreaShape(points: points, bottomY: plotRect.maxY)
                        .fill(
                            LinearGradient(
                                colors: [
                                    MHBTheme.ColorToken.primary.color.opacity(0.16),
                                    MHBTheme.ColorToken.primary.color.opacity(0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    PetWeightLineShape(points: points)
                        .stroke(
                            MHBTheme.ColorToken.primary.color,
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                        )

                    if let lastPoint = points.last,
                       let lastRecord = orderedRecords.last {
                        Circle()
                            .fill(MHBTheme.ColorToken.cardSolid.color)
                            .overlay {
                                Circle()
                                    .strokeBorder(MHBTheme.ColorToken.primary.color, lineWidth: 2.5)
                            }
                            .frame(width: 9, height: 9)
                            .position(lastPoint)

                        Text(String(format: "%.2fkg", lastRecord.weight))
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, MHBTheme.Spacing.s2)
                            .frame(height: 18)
                            .background(MHBTheme.ColorToken.primary.color, in: Capsule())
                            .position(x: min(lastPoint.x - 20, plotRect.maxX - 28), y: max(lastPoint.y - 18, 12))
                    }
                }
            }
        }
    }

    private func chartPoints(in rect: CGRect) -> [CGPoint] {
        let values = orderedRecords.map(\.weight)
        guard let minValue = values.min(),
              let maxValue = values.max(),
              values.count > 1 else {
            return []
        }

        let valueRange = max(maxValue - minValue, 0.1)
        return values.enumerated().map { index, value in
            let xProgress = CGFloat(index) / CGFloat(values.count - 1)
            let yProgress = CGFloat((value - minValue) / valueRange)
            return CGPoint(
                x: rect.minX + rect.width * xProgress,
                y: rect.maxY - rect.height * yProgress
            )
        }
    }
}

// PetWeightGridLines 体重图表网格线
// 核心职责：
// - 绘制纵向刻度和横向参考线
// - 保持图表读数层次克制
struct PetWeightGridLines: View {
    let plotRect: CGRect

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(gridRows, id: \.label) { row in
                Text(row.label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
                    .position(x: 14, y: plotRect.minY + plotRect.height * row.progress)

                Path { path in
                    let y = plotRect.minY + plotRect.height * row.progress
                    path.move(to: CGPoint(x: plotRect.minX, y: y))
                    path.addLine(to: CGPoint(x: plotRect.maxX, y: y))
                }
                .stroke(
                    MHBTheme.ColorToken.separator.color,
                    style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                )
            }
        }
    }

    private var gridRows: [(label: String, progress: CGFloat)] {
        [
            ("4.50", 0),
            ("4.20", 0.5),
            ("3.90", 1)
        ]
    }
}

// PetWeightLineShape 体重折线路径
// 核心职责：
// - 通过二次曲线连接图表点位
struct PetWeightLineShape: Shape {
    let points: [CGPoint]

    nonisolated func path(in _: CGRect) -> Path {
        Path { path in
            guard let firstPoint = points.first else { return }
            path.move(to: firstPoint)

            for index in 1..<points.count {
                let previous = points[index - 1]
                let current = points[index]
                let control = CGPoint(
                    x: (previous.x + current.x) / 2,
                    y: previous.y
                )
                path.addQuadCurve(to: current, control: control)
            }
        }
    }
}

// PetWeightAreaShape 体重图表面积路径
// 核心职责：
// - 为折线下方绘制渐隐填充区域
struct PetWeightAreaShape: Shape {
    let points: [CGPoint]
    let bottomY: CGFloat

    nonisolated func path(in rect: CGRect) -> Path {
        var path = PetWeightLineShape(points: points).path(in: rect)
        if let lastPoint = points.last,
           let firstPoint = points.first {
            path.addLine(to: CGPoint(x: lastPoint.x, y: bottomY))
            path.addLine(to: CGPoint(x: firstPoint.x, y: bottomY))
            path.closeSubpath()
        }
        return path
    }
}
