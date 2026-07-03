import SwiftUI
import MaohuobanDesignSystem
import UIKit

// PetAlbumDetailScreen 宠物相册详情页
// 核心职责：
// - 展示单个相册的标题、数量和照片墙
// - 通过相册 Store 加载并展示后端照片资源
struct PetAlbumDetailScreen: View {
    @Environment(\.dismiss) private var dismiss

    let albumID: String
    let store: PetAlbumStore
    @State private var pendingDeleteAsset: PetAlbumAsset?
    @State private var isPhotoPickerPresented = false
    @State private var isSelectionMode = false
    @State private var selectedAssetIDs: Set<String> = []
    @State private var windowSafeAreaInsets = UIEdgeInsets.zero
    @State private var isDeleteSelectionConfirmationPresented = false

    var body: some View {
        let album = resolvedAlbum
        let assets = store.assets(for: album.id)
        let uploadPlaceholders = store.uploadPlaceholders(for: album.id)

        GeometryReader { proxy in
            let topInset = max(proxy.safeAreaInsets.top, windowSafeAreaInsets.top)
            let bottomInset = max(proxy.safeAreaInsets.bottom, windowSafeAreaInsets.bottom)
            let heroHeight = PetAlbumDetailLayout.heroHeight(viewportHeight: proxy.size.height)

            ZStack(alignment: .topLeading) {
                MHBTheme.ColorToken.cardSolid.color
                    .ignoresSafeArea()

                PetAlbumDetailContent(
                    album: album,
                    assets: assets,
                    heroHeight: heroHeight,
                    containerWidth: proxy.size.width,
                    containerHeight: proxy.size.height,
                    bottomContentInset: bottomContentInset(bottomInset: bottomInset),
                    uploadPlaceholders: uploadPlaceholders,
                    selectedAssetIDs: selectedAssetIDs,
                    isSelectionMode: isSelectionMode,
                    onToggleSelection: toggleSelection,
                    onDeleteAsset: { asset in
                        pendingDeleteAsset = asset
                    },
                    onUpload: {
                        isPhotoPickerPresented = true
                    }
                )
                .frame(width: proxy.size.width, height: proxy.size.height)
                .zIndex(0)

                MHBWindowSafeAreaReader { insets in
                    windowSafeAreaInsets = insets
                }
                .allowsHitTesting(false)

                PetAlbumDetailTopChrome(
                    isSelectionMode: isSelectionMode,
                    onBack: { dismiss() },
                    onToggleSelectionMode: toggleSelectionMode,
                    onSelectAll: { selectAll(assets: assets) },
                    onShare: handleShareTodo
                )
                .padding(.horizontal, MHBTheme.Spacing.s4)
                .padding(.top, topInset + MHBTheme.Spacing.s1)
                .frame(width: proxy.size.width, alignment: .top)
                .zIndex(3)

                PetAlbumDetailBottomChrome(
                    isSelectionMode: isSelectionMode,
                    selectedCount: selectedAssetIDs.count,
                    bottomInset: bottomInset,
                    onUpload: {
                        isPhotoPickerPresented = true
                    },
                    onShare: handleShareTodo,
                    onDeleteSelection: {
                        requestDeleteSelectedAssets()
                    }
                )
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottom)
                .zIndex(3)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
        .ignoresSafeArea(.container, edges: [.top, .bottom])
        .task(id: albumID) {
            await store.loadAssets(for: albumID)
        }
        .mhbImagePreviewHost()
        .fullScreenCover(isPresented: $isPhotoPickerPresented) {
            MHBMediaPickerScreen(
                title: "上传照片",
                request: MHBMediaPickerRequest(
                    maxSelectionCount: 9,
                    filter: .images,
                    disabledLocalIdentifiers: disabledLocalIdentifiers
                ),
                onComplete: handlePhotoPickerResult,
                onCancel: {
                    isPhotoPickerPresented = false
                }
            )
        }
        .alert(
            "删除照片",
            isPresented: deleteAssetAlertBinding,
            presenting: pendingDeleteAsset
        ) { asset in
            Button("删除照片", role: .destructive) {
                Task {
                    await store.deleteAsset(id: asset.id, in: asset.albumID)
                }
                pendingDeleteAsset = nil
            }

            Button("取消", role: .cancel) {
                pendingDeleteAsset = nil
            }
        } message: { _ in
            Text("将从当前相册中删除这张照片。")
        }
        .alert(
            "删除已选照片",
            isPresented: $isDeleteSelectionConfirmationPresented
        ) {
            Button("删除照片", role: .destructive) {
                deleteSelectedAssets(assets: assets)
            }

            Button("取消", role: .cancel) {}
        } message: {
            Text("将从当前相册中删除已选的 \(selectedAssetIDs.count) 张照片。")
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .accessibilityIdentifier("petAlbum.detail.screen")
    }

    private var deleteAssetAlertBinding: Binding<Bool> {
        Binding(
            get: { pendingDeleteAsset != nil },
            set: { isPresented in
                if isPresented == false {
                    pendingDeleteAsset = nil
                }
            }
        )
    }

    private var resolvedAlbum: PetAlbumSummary {
        if let album = store.album(id: albumID) {
            return album
        }

        return PetAlbumSummary(
            id: albumID,
            title: "宠物相册",
            petName: "全部宠物",
            updatedText: "刚刚更新",
            photoCount: 0,
            coverImageAssetName: "photo.on.rectangle.angled"
        )
    }

    private var disabledLocalIdentifiers: Set<String> {
        Set(store.assets(for: albumID).compactMap(\.localIdentifier))
    }

    private func bottomContentInset(bottomInset: CGFloat) -> CGFloat {
        PetAlbumDetailLayout.chromeIconSize + bottomInset
    }

    private func toggleSelectionMode() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isSelectionMode.toggle()
            if !isSelectionMode {
                selectedAssetIDs.removeAll()
                isDeleteSelectionConfirmationPresented = false
            }
        }
    }

    private func selectAll(assets: [PetAlbumAsset]) {
        selectedAssetIDs = Set(assets.map(\.id))
    }

    private func toggleSelection(_ asset: PetAlbumAsset) {
        guard isSelectionMode else {
            return
        }

        if selectedAssetIDs.contains(asset.id) {
            selectedAssetIDs.remove(asset.id)
        } else {
            selectedAssetIDs.insert(asset.id)
        }
    }

    private func requestDeleteSelectedAssets() {
        guard selectedAssetIDs.isEmpty == false else {
            return
        }

        isDeleteSelectionConfirmationPresented = true
    }

    private func deleteSelectedAssets(assets: [PetAlbumAsset]) {
        let selectedAssets = assets.filter { selectedAssetIDs.contains($0.id) }
        guard !selectedAssets.isEmpty else {
            return
        }

        Task {
            for asset in selectedAssets {
                await store.deleteAsset(id: asset.id, in: asset.albumID)
            }
            selectedAssetIDs.removeAll()
            isSelectionMode = false
        }
    }

    private func handleShareTodo() {
        // TODO: 接入相册分享流程。
    }

    // handlePhotoPickerResult 处理相册照片选择结果
    // 核心职责：
    // - 将媒体选择器返回的图片编码为相册上传草稿
    // - 通过 Store 完成上传与相册绑定
    private func handlePhotoPickerResult(_ result: MHBMediaPickerResult) {
        isPhotoPickerPresented = false
        var drafts: [PetAlbumPhotoUploadDraft] = []
        for (index, image) in result.images.enumerated() {
            let localIdentifier = result.imageLocalIdentifiers.indices.contains(index)
                ? result.imageLocalIdentifiers[index]
                : nil
            guard let draft = photoUploadDraft(
                from: image,
                localIdentifier: localIdentifier,
                index: index
            ) else {
                continue
            }
            drafts.append(draft)
        }
        guard !drafts.isEmpty else {
            return
        }

        Task {
            _ = await store.uploadPhotos(to: albumID, drafts: drafts)
        }
    }

    private func photoUploadDraft(
        from image: UIImage,
        localIdentifier: String?,
        index: Int
    ) -> PetAlbumPhotoUploadDraft? {
        guard let encoded = MHBMediaUploadEncoder.encode(
            image: image,
            purpose: .ugcImage,
            fileName: "pet-album-photo-\(index + 1)"
        ) else {
            return nil
        }

        let media = PetMediaUploadDraft(
            fileName: encoded.fileName,
            mimeType: encoded.mimeType,
            content: encoded.data,
            sourceClient: "ios"
        )
        return PetAlbumPhotoUploadDraft(
            media: media,
            localIdentifier: localIdentifier,
            previewData: encoded.data
        )
    }
}
