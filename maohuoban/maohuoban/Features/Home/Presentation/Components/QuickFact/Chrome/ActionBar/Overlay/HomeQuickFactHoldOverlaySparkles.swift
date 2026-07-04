import SwiftUI
import MaohuobanDesignSystem

// HomeQuickFactHoldOverlaySparkles 快捷事实完成粒子
// 核心职责：
// - 在中心浮层完成阶段呈现扩散粒子
// - 只服务视觉反馈，不参与提交状态
struct HomeQuickFactHoldOverlaySparkles: View {
    let accentColor: Color
    let isActive: Bool

    var body: some View {
        ZStack {
            ForEach(0..<10, id: \.self) { index in
                Circle()
                    .fill(accentColor.opacity(isActive ? 0.72 : 0))
                    .frame(width: sparkleSize(index: index), height: sparkleSize(index: index))
                    .offset(sparkleOffset(index: index))
                    .scaleEffect(isActive ? 1 : 0.2)
                    .opacity(isActive ? 1 : 0)
                    .animation(
                        .snappy(duration: 0.42).delay(Double(index) * 0.018),
                        value: isActive
                    )
            }
        }
    }

    private func sparkleSize(index: Int) -> CGFloat {
        index.isMultiple(of: 2) ? 5 : 3.5
    }

    private func sparkleOffset(index: Int) -> CGSize {
        let angle = (Double(index) / 10) * Double.pi * 2
        let distance = isActive ? 76.0 : 34.0
        return CGSize(
            width: cos(angle) * distance,
            height: sin(angle) * distance
        )
    }
}
