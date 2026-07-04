import SwiftUI

// MHBPhotoLibraryAuthorizedContent 已授权照片内容
// 核心职责：
// - 展示有限访问提示和资源网格
// - 在加载、空态和网格之间切换
struct MHBPhotoLibraryAuthorizedContent: View {
    let authorizationStatus: MHBPhotoLibraryAuthorizationStatus
    let isLoading: Bool
    let isResolvingSelection: Bool
    let assets: [MHBPhotoLibraryAsset]
    let resolvingAssetID: String?
    let selectedAssetIDs: [String: Int]
    let disabledAssetIDs: Set<String>
    let showsCameraEntry: Bool
    let service: MHBPhotoLibraryService
    let onSelectAsset: (MHBPhotoLibraryAsset) -> Void
    let onSelectDisabledAsset: (MHBPhotoLibraryAsset) -> Void
    let onSelectCamera: () -> Void
    let onOpenLimitedPicker: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            if authorizationStatus == .limited {
                MHBPhotoLibraryLimitedBanner(onOpenLimitedPicker: onOpenLimitedPicker)
            }

            if isLoading {
                MHBPhotoLibraryLoadingView(text: "正在加载照片...")
            } else if assets.isEmpty && !showsCameraEntry {
                MHBPhotoLibraryEmptyView()
            } else {
                MHBPhotoGridViewRepresentable(
                    assets: assets,
                    resolvingAssetID: resolvingAssetID,
                    selectedAssetIDs: selectedAssetIDs,
                    disabledAssetIDs: disabledAssetIDs,
                    showsCameraEntry: showsCameraEntry,
                    service: service,
                    onSelectAsset: onSelectAsset,
                    onSelectDisabledAsset: onSelectDisabledAsset,
                    onSelectCamera: onSelectCamera
                )
                .disabled(isResolvingSelection)
            }
        }
    }
}
