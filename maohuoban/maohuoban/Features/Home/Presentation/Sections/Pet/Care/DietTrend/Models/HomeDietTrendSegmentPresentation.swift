import SwiftUI
import MaohuobanDesignSystem

// HomeDietTrendSegmentPresentation 首页饮食趋势分段展示模型
// 核心职责：
// - 承载趋势条和图例渲染所需的窄字段
// - 为不同饮食品类提供稳定颜色映射
struct HomeDietTrendSegmentPresentation: Identifiable {
    let id: String
    let title: String
    let percentage: Int
    let percentageText: String
    let scoreText: String
    let baselineText: String
    let ratioText: String
    let emaText: String
    let baselineSampleText: String
    let color: Color

    init(segment: PetDietTrendSegment) {
        self.id = segment.category
        self.title = segment.title
        self.percentage = segment.percentage
        self.percentageText = "\(segment.percentage)%"
        self.scoreText = Self.scoreText(segment.score)
        self.baselineText = if segment.category == "other" {
            "不参与基线"
        } else {
            segment.baselineScore.map(Self.scoreText) ?? "样本不足"
        }
        self.ratioText = segment.currentRatio.map { "\(($0 * 100).roundedInt())%" } ?? "--"
        self.emaText = segment.emaScore.map(Self.scoreText) ?? "--"
        self.baselineSampleText = "\(segment.baselineSampleDays) 天"
        self.color = Self.color(for: segment.category)
    }

    private static func scoreText(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)))
    }

    private static func color(for category: String) -> Color {
        switch category {
        case "main_food":
            return MHBTheme.ColorToken.primary.color
        case "wet_food":
            return .cyan
        case "treats":
            return .pink
        case "nutrition":
            return .green
        case "other":
            return .orange
        default:
            return MHBTheme.ColorToken.labelSecondary.color
        }
    }
}

private extension Double {
    func roundedInt() -> Int {
        Int(rounded())
    }
}
