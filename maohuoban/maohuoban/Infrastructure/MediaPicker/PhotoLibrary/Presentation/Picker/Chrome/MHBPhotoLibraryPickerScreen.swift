import SwiftUI
import UIKit

// MHBPhotoLibraryPickerScreen PhotoKit 照片选择页
// 核心职责：
// - 提供图片、视频和 Live Photo 统一选择入口
// - 将用户选择转换为通用媒体选择结果回传业务层
struct MHBPhotoLibraryPickerScreen: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let request: MHBMediaPickerRequest
    let onComplete: (MHBMediaPickerResult) -> Void
    let onCancel: () -> Void

    @State private var store: MHBPhotoLibraryPickerStore
    @State private var isAlbumPickerPresented = false
    @State private var isLimitedPickerPresented = false
    @State private var isCameraPresented = false
    @State private var isCameraFailureAlertPresented = false
    @State private var cameraFailureMessage = ""
    @State private var resolvingAssetID: String?

    init(
        title: String = "选择照片",
        request: MHBMediaPickerRequest = .singleImage,
        onComplete: @escaping (MHBMediaPickerResult) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.title = title
        self.request = request
        self.onComplete = onComplete
        self.onCancel = onCancel
        _store = State(initialValue: MHBPhotoLibraryPickerStore(request: request))
    }

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                MHBPhotoLibraryPickerHeader(
                    title: title,
                    albumTitle: store.currentAlbum?.title,
                    onCancel: handleCancel,
                    onToggleAlbums: handleToggleAlbums
                )

                MHBPhotoLibraryPickerContent(
                    authorizationStatus: store.authorizationStatus,
                    isLoading: store.isLoading,
                    isResolvingSelection: store.isResolvingSelection,
                    assets: store.assets,
                    resolvingAssetID: resolvingAssetID,
                    selectedAssetIDs: store.selectedAssetIDMap,
                    disabledAssetIDs: store.disabledAssetIDs,
                    showsCameraEntry: request.showsCameraEntry,
                    service: store.service,
                    onSelectAsset: handleSelectAsset,
                    onSelectDisabledAsset: handleSelectDisabledAsset,
                    onSelectCamera: handleSelectCamera,
                    onOpenSettings: openSettings,
                    onOpenLimitedPicker: {
                        isLimitedPickerPresented = true
                    }
                )

                if !request.autoConfirmSingleSelection {
                    MHBPhotoLibraryPickerBottomBar(
                        selectedCountText: store.selectedCountText,
                        hasSelection: store.hasSelection,
                        isResolvingSelection: store.isResolvingSelection,
                        onConfirm: handleConfirm
                    )
                }
            }

            MHBPhotoLibraryAlbumPickerView(
                isPresented: isAlbumPickerPresented,
                albums: store.albums,
                currentAlbumID: store.currentAlbum?.id,
                filter: request.filter,
                service: store.service,
                topOffset: 63,
                onDismiss: handleDismissAlbums,
                onSelect: handleSelectAlbum
            )
        }
        .background(Color.black.ignoresSafeArea())
        .task {
            await store.load()
        }
        .onDisappear {
            store.cleanup()
        }
        .sheet(isPresented: $isLimitedPickerPresented) {
            MHBPhotoLibraryLimitedPickerPresenter {
                isLimitedPickerPresented = false
                Task { await store.reloadCurrentAlbum() }
            }
            .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $isCameraPresented) {
            MHBResponsiveCameraImagePicker(
                onComplete: handleCameraComplete(_:),
                onCancel: {
                    isCameraPresented = false
                },
                onFailure: { message in
                    isCameraPresented = false
                    presentCameraFailure(message)
                }
            )
            .ignoresSafeArea()
        }
        .alert(
            "照片读取失败",
            isPresented: Binding(
                get: { store.errorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        store.errorMessage = nil
                    }
                }
            )
        ) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(store.errorMessage ?? "请重新选择照片")
        }
        .alert(
            "无法打开相机",
            isPresented: $isCameraFailureAlertPresented
        ) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(cameraFailureMessage)
        }
    }

    private func handleCancel() {
        onCancel()
        dismiss()
    }

    private func handleToggleAlbums() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            isAlbumPickerPresented.toggle()
        }
    }

    private func handleDismissAlbums() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            isAlbumPickerPresented = false
        }
    }

    private func handleSelectAlbum(_ album: MHBPhotoLibraryAlbum) {
        handleDismissAlbums()
        Task {
            await store.selectAlbum(album)
        }
    }

    private func handleSelectAsset(_ asset: MHBPhotoLibraryAsset) {
        guard !store.isResolvingSelection else {
            return
        }

        guard request.autoConfirmSingleSelection else {
            store.toggleSelection(for: asset)
            return
        }

        resolvingAssetID = asset.id
        Task {
            let result = await store.resolveSelection(for: asset)
            resolvingAssetID = nil
            guard let result else {
                return
            }
            onComplete(result)
            dismiss()
        }
    }

    private func handleSelectDisabledAsset(_ asset: MHBPhotoLibraryAsset) {
        store.handleDisabledSelection(for: asset)
        MHBToastPresenter().warning(store.inlineMessage ?? "这张照片已在当前相册中")
    }

    private func handleSelectCamera() {
        guard MHBResponsiveCameraImagePicker.isCameraAvailable else {
            presentCameraFailure("当前设备没有可用相机")
            return
        }
        isCameraPresented = true
    }

    private func handleCameraComplete(_ image: UIImage) {
        isCameraPresented = false
        onComplete(MHBMediaPickerResult(images: [image]))
        dismiss()
    }

    private func handleConfirm() {
        guard store.hasSelection else {
            return
        }

        Task {
            guard let result = await store.resolveSelectedAssets() else {
                return
            }
            onComplete(result)
            dismiss()
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        UIApplication.shared.open(url)
    }

    private func presentCameraFailure(_ message: String) {
        cameraFailureMessage = message
        isCameraFailureAlertPresented = true
    }
}
