import SwiftUI

// TimelineDotLine 时间线纵向连接线和圆点
// 核心职责：
// - 绘制时间线行的竖线和居中圆点
// - 首尾行分别屏蔽上下半段垂直线
struct TimelineDotLine: View {
    let isFirst: Bool
    let isLast: Bool

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                if isFirst {
                    Color.clear
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                } else {
                    Rectangle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                }

                if isLast {
                    Color.clear
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                } else {
                    Rectangle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                }
            }

            Circle()
                .fill(Color.white.opacity(0.5))
                .frame(width: 6, height: 6)
        }
        .frame(width: 16)
    }
}
