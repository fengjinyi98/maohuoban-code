import SwiftUI
import MaohuobanDesignSystem
import UIKit

// PetAlbumAssetImage 宠物相册图片展示组件
// 核心职责：
// - 统一渲染相册后端图片资源
// - 提供稳定占位背景和裁切策略
struct PetAlbumAssetImage: View {
    let imageAssetName: String

    var body: some View {
        if let url = PetAlbumImageSourceResolver.remoteURL(from: imageAssetName) {
            MHBRemoteImage(url: url) {
                placeholder
            }
            .background(MHBTheme.ColorToken.separatorSoft.color)
        } else if UIImage(named: imageAssetName) != nil {
            Image(imageAssetName)
                .resizable()
                .scaledToFill()
                .background(MHBTheme.ColorToken.separatorSoft.color)
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        ZStack {
            MHBTheme.ColorToken.separatorSoft.color
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: MHBTheme.IconSize.large, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelQuaternary.color)
        }
    }
}
