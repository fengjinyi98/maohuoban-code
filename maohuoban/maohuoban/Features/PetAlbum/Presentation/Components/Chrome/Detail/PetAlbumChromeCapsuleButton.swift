import SwiftUI
import MaohuobanDesignSystem

// PetAlbumChromeCapsuleButton 相册沉浸式胶囊按钮
// 核心职责：
// - 承载选择、全选等文字操作
// - 统一 Liquid Glass 胶囊按钮样式
struct PetAlbumChromeCapsuleButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(MHBTheme.Typography.callout.weight(.semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .padding(.horizontal, MHBTheme.Spacing.s4)
                .frame(height: PetAlbumDetailLayout.chromeIconSize)
                .background {
                    Color.white.opacity(0.18)
                        .clipShape(Capsule())
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .capsule)
        .accessibilityLabel(title)
    }
}
