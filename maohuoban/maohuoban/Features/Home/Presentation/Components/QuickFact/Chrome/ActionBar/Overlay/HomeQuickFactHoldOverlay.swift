import SwiftUI
import MaohuobanDesignSystem

// HomeQuickFactHoldOverlay 快捷事实长按确认浮层
// 核心职责：
// - 在屏幕中心展示按住确认进度和完成反馈
// - 将仪式感动效从底部按钮本体中隔离
struct HomeQuickFactHoldOverlay: View {
    let controller: HomeQuickFactHoldController

    var body: some View {
        ZStack {
            if let state = controller.overlayState {
                HomeQuickFactHoldOverlayPanel(state: state)
                    .transition(.scale(scale: 0.88).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
        .animation(.snappy(duration: 0.22), value: controller.overlayState)
    }
}
