import SwiftUI
import UIKit

// MHBPhotoGridViewRepresentable PhotoKit 网格 SwiftUI 桥接
// 核心职责：
// - 将 UIKit UICollectionView 网格嵌入 SwiftUI 页面
// - 同步资源列表、解析状态和选择事件
struct MHBPhotoGridViewRepresentable: UIViewRepresentable {
    let assets: [MHBPhotoLibraryAsset]
    let resolvingAssetID: String?
    let service: MHBPhotoLibraryService
    let onSelectAsset: (MHBPhotoLibraryAsset) -> Void

    func makeUIView(context: Context) -> UICollectionView {
        let controller = MHBPhotoGridController(service: service)
        controller.assets = assets
        controller.resolvingAssetID = resolvingAssetID
        controller.onSelectAsset = onSelectAsset
        context.coordinator.controller = controller
        return controller.collectionView
    }

    func updateUIView(_ uiView: UICollectionView, context: Context) {
        guard let controller = context.coordinator.controller else {
            return
        }

        if controller.assets.map(\.id) != assets.map(\.id) {
            controller.assets = assets
        }
        controller.onSelectAsset = onSelectAsset
        controller.updateResolvingAssetID(resolvingAssetID)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var controller: MHBPhotoGridController?
    }
}
