import SwiftUI
import MaohuobanDesignSystem

// PetAlbumAssetImage 宠物相册图片展示组件
// 核心职责：
// - 统一渲染相册本地 Mock 图片资源
// - 提供稳定占位背景和裁切策略
struct PetAlbumAssetImage: View {
    let imageAssetName: String

    var body: some View {
        Image(imageAssetName)
            .resizable()
            .scaledToFill()
            .background(MHBTheme.ColorToken.separatorSoft.color)
    }
}
