import SwiftUI
import UIKit

// MHBPhotoGridViewRepresentable PhotoKit 网格 SwiftUI 桥接
// 核心职责：
// - 将 UIKit UICollectionView 网格容器嵌入 SwiftUI 页面
// - 同步资源列表、解析状态和选择事件
struct MHBPhotoGridViewRepresentable: UIViewControllerRepresentable {
    let assets: [MHBPhotoLibraryAsset]
    let resolvingAssetID: String?
    let selectedAssetIDs: [String: Int]
    let disabledAssetIDs: Set<String>
    let showsCameraEntry: Bool
    let service: MHBPhotoLibraryService
    let onSelectAsset: (MHBPhotoLibraryAsset) -> Void
    let onSelectDisabledAsset: (MHBPhotoLibraryAsset) -> Void
    let onSelectCamera: () -> Void

    func makeUIViewController(context: Context) -> MHBPhotoGridContainerController {
        let controller = MHBPhotoGridController(service: service)
        controller.assets = assets
        controller.resolvingAssetID = resolvingAssetID
        controller.selectedAssetIDs = selectedAssetIDs
        controller.disabledAssetIDs = disabledAssetIDs
        controller.showsCameraEntry = showsCameraEntry
        controller.onSelectAsset = onSelectAsset
        controller.onSelectDisabledAsset = onSelectDisabledAsset
        controller.onSelectCamera = onSelectCamera
        context.coordinator.controller = controller
        return MHBPhotoGridContainerController(gridController: controller)
    }

    func updateUIViewController(
        _ uiViewController: MHBPhotoGridContainerController,
        context: Context
    ) {
        guard let controller = context.coordinator.controller else {
            return
        }

        if controller.assets.map(\.id) != assets.map(\.id) {
            controller.assets = assets
        }
        if controller.showsCameraEntry != showsCameraEntry {
            controller.showsCameraEntry = showsCameraEntry
        }
        controller.onSelectAsset = onSelectAsset
        controller.onSelectDisabledAsset = onSelectDisabledAsset
        controller.onSelectCamera = onSelectCamera
        controller.updateResolvingAssetID(resolvingAssetID)
        controller.updateSelectedAssetIDs(selectedAssetIDs)
        controller.updateDisabledAssetIDs(disabledAssetIDs)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var controller: MHBPhotoGridController?
    }
}
