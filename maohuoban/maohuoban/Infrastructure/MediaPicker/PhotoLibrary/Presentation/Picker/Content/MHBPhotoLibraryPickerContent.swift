import SwiftUI

// MHBPhotoLibraryPickerContent 照片选择器内容区
// 核心职责：
// - 根据授权、加载和空态展示对应内容
// - 承载照片网格和 Limited Library 提示
struct MHBPhotoLibraryPickerContent: View {
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
    let onOpenSettings: () -> Void
    let onOpenLimitedPicker: () -> Void

    var body: some View {
        switch authorizationStatus {
        case .notDetermined:
            MHBPhotoLibraryLoadingView(text: "正在读取照片...")
        case .restricted, .denied:
            MHBPhotoLibraryPermissionView(onOpenSettings: onOpenSettings)
        case .authorized, .limited:
            MHBPhotoLibraryAuthorizedContent(
                authorizationStatus: authorizationStatus,
                isLoading: isLoading,
                isResolvingSelection: isResolvingSelection,
                assets: assets,
                resolvingAssetID: resolvingAssetID,
                selectedAssetIDs: selectedAssetIDs,
                disabledAssetIDs: disabledAssetIDs,
                showsCameraEntry: showsCameraEntry,
                service: service,
                onSelectAsset: onSelectAsset,
                onSelectDisabledAsset: onSelectDisabledAsset,
                onSelectCamera: onSelectCamera,
                onOpenLimitedPicker: onOpenLimitedPicker
            )
        }
    }
}
