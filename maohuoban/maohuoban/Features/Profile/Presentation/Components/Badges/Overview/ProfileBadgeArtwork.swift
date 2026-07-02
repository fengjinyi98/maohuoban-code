import SwiftUI
import MaohuobanDesignSystem

// ProfileBadgeArtwork 勋章资源图片视图
// 核心职责：
// - 统一渲染本地 mock 勋章图片资源
// - 根据点亮状态提供首页卡片、完整网格和详情弹层共用的视觉状态
struct ProfileBadgeArtwork: View {
    let imageAssetName: String
    let isEarned: Bool
    let size: CGFloat
    let shadowRadius: CGFloat

    var body: some View {
        Image(imageAssetName)
            .resizable()
            .scaledToFit()
            .saturation(isEarned ? 1 : 0)
            .opacity(isEarned ? 1 : 0.36)
            .frame(width: size, height: size)
            .shadow(
                color: MHBTheme.ColorToken.labelPrimary.color.opacity(isEarned ? 0.08 : 0),
                radius: shadowRadius,
                x: 0,
                y: max(shadowRadius / 2, 1)
            )
            .accessibilityHidden(true)
    }
}
