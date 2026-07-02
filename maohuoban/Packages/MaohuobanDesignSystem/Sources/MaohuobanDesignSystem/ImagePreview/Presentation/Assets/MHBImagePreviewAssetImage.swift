import SwiftUI

// MHBImagePreviewAssetImage 预览资源图片视图
// 核心职责：
// - 统一渲染本地资源图和远端图片，保持 source 与 Overlay 视觉一致
// - 禁止在 body 里做存在性探测等同步 IO，交给底层图片组件处理
struct MHBImagePreviewAssetImage: View {
    let asset: MHBImagePreviewAsset
    let contentMode: ContentMode
    let cornerRadius: CGFloat

    var body: some View {
        switch asset.sourceKind {
        case let .localAsset(name):
            Color.clear
                .overlay {
                    Image(name)
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                }
                .clipShape(.rect(cornerRadius: cornerRadius))

        case let .remote(urlString):
            MHBRemoteImage(
                source: urlString,
                contentMode: contentMode,
                cornerRadius: cornerRadius
            ) {
                placeholder
            }

        case let .systemSymbol(symbolName):
            Color.clear
                .overlay {
                    Image(systemName: symbolName)
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                }
                .clipShape(.rect(cornerRadius: cornerRadius))

        case .empty:
            placeholder
        }
    }

    private var placeholder: some View {
        Color.clear
            .overlay {
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
            }
    }
}
