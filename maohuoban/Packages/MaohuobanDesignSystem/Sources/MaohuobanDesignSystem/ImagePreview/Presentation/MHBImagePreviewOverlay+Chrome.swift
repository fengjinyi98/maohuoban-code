import SwiftUI

// MHBImagePreviewOverlay 顶部工具栏扩展
// 核心职责：
// - 承载关闭按钮与页面指示器
extension MHBImagePreviewOverlay {
    func topBar() -> some View {
        HStack(spacing: 12) {
            Button(action: dismissByButton) {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .contentShape(.circle)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .circle)
            .accessibilityLabel("关闭大图预览")

            Spacer(minLength: 12)

            Button(action: {}) {
                Text(session.pageIndicatorText)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .frame(height: 34)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular, in: .capsule)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .padding(.horizontal, 16)
    }
}
