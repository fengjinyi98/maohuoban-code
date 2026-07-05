import SwiftUI
import MaohuobanDesignSystem

// HomeAttentionHintMarqueeText 首页轻提示跑马灯文本
// 核心职责：
// - 展示后端返回的轻提示文案
// - 文案超出可用宽度时自动横向滚动
struct HomeAttentionHintMarqueeText: View {
    let text: String

    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0

    private var shouldScroll: Bool {
        textWidth > containerWidth && containerWidth > 0
    }

    private var travelDistance: CGFloat {
        max(textWidth - containerWidth + MHBTheme.Spacing.s5, 0)
    }

    var body: some View {
        GeometryReader { proxy in
            TimelineView(.animation) { context in
                let offset = scrollingOffset(at: context.date)

                Text(text)
                    .font(MHBTheme.Typography.callout.weight(.medium))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .background(widthReader)
                    .offset(x: offset)
            }
            .onAppear {
                containerWidth = proxy.size.width
            }
            .onChange(of: proxy.size.width) { _, newValue in
                containerWidth = newValue
            }
        }
        .frame(height: 22)
        .clipped()
        .accessibilityLabel(text)
    }

    private var widthReader: some View {
        GeometryReader { proxy in
            Color.clear
                .onAppear {
                    textWidth = proxy.size.width
                }
                .onChange(of: proxy.size.width) { _, newValue in
                    textWidth = newValue
                }
        }
    }

    private func scrollingOffset(at date: Date) -> CGFloat {
        guard shouldScroll else { return 0 }
        let cycleDuration = max(TimeInterval(travelDistance / 18), 3.5) + 1.4
        let progress = date.timeIntervalSinceReferenceDate.truncatingRemainder(
            dividingBy: cycleDuration
        ) / cycleDuration
        if progress < 0.18 {
            return 0
        }
        if progress > 0.88 {
            return -travelDistance
        }
        let normalized = (progress - 0.18) / 0.70
        return -travelDistance * normalized
    }
}
