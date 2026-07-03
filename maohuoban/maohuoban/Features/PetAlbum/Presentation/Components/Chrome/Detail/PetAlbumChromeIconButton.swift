import SwiftUI
import MaohuobanDesignSystem

// PetAlbumChromeIconButton 相册沉浸式图标按钮
// 核心职责：
// - 承载顶部和底部浮层的单图标操作
// - 统一 Liquid Glass 圆形按钮尺寸与命中区域
struct PetAlbumChromeIconButton: View {
    let systemImage: String
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: MHBTheme.IconSize.small, weight: .bold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .frame(
                    width: PetAlbumDetailLayout.chromeIconSize,
                    height: PetAlbumDetailLayout.chromeIconSize
                )
                .background {
                    Color.white.opacity(0.18)
                        .clipShape(Circle())
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel(accessibilityLabel)
    }
}
