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
    let service: MHBPhotoLibraryService
    let onSelectAsset: (MHBPhotoLibraryAsset) -> Void
    let onSelectDisabledAsset: (MHBPhotoLibraryAsset) -> Void
    let onOpenLimitedPicker: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            if authorizationStatus == .limited {
                MHBPhotoLibraryLimitedBanner(onOpenLimitedPicker: onOpenLimitedPicker)
            }

            if isLoading {
                MHBPhotoLibraryLoadingView(text: "正在加载照片...")
            } else if assets.isEmpty {
                MHBPhotoLibraryEmptyView()
            } else {
                MHBPhotoGridViewRepresentable(
                    assets: assets,
                    resolvingAssetID: resolvingAssetID,
                    selectedAssetIDs: selectedAssetIDs,
                    disabledAssetIDs: disabledAssetIDs,
                    service: service,
                    onSelectAsset: onSelectAsset,
                    onSelectDisabledAsset: onSelectDisabledAsset
                )
                .disabled(isResolvingSelection)
            }
        }
    }
}
