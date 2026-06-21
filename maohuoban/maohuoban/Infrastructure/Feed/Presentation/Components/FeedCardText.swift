import SwiftUI
import MaohuobanDesignSystem

// FeedCardText Feed 卡片正文
// 核心职责：
// - 展示 Feed 卡片正文内容
// - 根据媒体圆角计算正文起点，避开图片圆角后的弧形区域
struct FeedCardText: View {
    let text: String
    let lineLimit: Int
    let font: Font
    let lineSpacing: CGFloat

    init(
        text: String,
        lineLimit: Int = 2,
        font: Font = .system(size: 16, weight: .medium),
        lineSpacing: CGFloat = 0
    ) {
        self.text = text
        self.lineLimit = lineLimit
        self.font = font
        self.lineSpacing = lineSpacing
    }

    var body: some View {
        Text(text)
            .font(font)
            .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
            .lineSpacing(lineSpacing)
            .lineLimit(lineLimit)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.leading, leadingInset)
            .padding(.trailing, MHBTheme.Spacing.s2)
    }

    private var leadingInset: CGFloat {
        FeedCardMetrics.mediaTextLeadingInset
    }
}
