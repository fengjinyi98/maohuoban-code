import SwiftUI

// MHBTimelineDotLine 通用时间线纵向连接线和圆点
// 核心职责：
// - 绘制时间线行的竖线和居中圆点
// - 支持不同页面按背景传入可见的线条和圆点颜色
struct MHBTimelineDotLine: View {
    let isFirst: Bool
    let isLast: Bool
    let lineColor: Color
    let dotColor: Color

    init(
        isFirst: Bool,
        isLast: Bool,
        lineColor: Color,
        dotColor: Color
    ) {
        self.isFirst = isFirst
        self.isLast = isLast
        self.lineColor = lineColor
        self.dotColor = dotColor
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                if isFirst {
                    Color.clear
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                } else {
                    Rectangle()
                        .fill(lineColor)
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                }

                if isLast {
                    Color.clear
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                } else {
                    Rectangle()
                        .fill(lineColor)
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                }
            }

            Circle()
                .fill(dotColor)
                .frame(width: 6, height: 6)
        }
        .frame(width: 16)
    }
}
