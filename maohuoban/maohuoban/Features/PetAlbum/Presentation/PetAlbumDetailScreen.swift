import SwiftUI
import MaohuobanDesignSystem
import UIKit

// PetAlbumDetailScreen 宠物相册详情页
// 核心职责：
// - 展示单个相册的标题、数量和照片墙
// - 通过相册 Store 加载并展示后端照片资源
struct PetAlbumDetailScreen: View {
    let albumID: String
    let store: PetAlbumStore
    @State private var pendingDeleteAsset: PetAlbumAsset?
    @State private var isNavigationTitleVisible = false
    @State private var isPhotoPickerPresented = false

    var body: some View {
        let album = resolvedAlbum
        let assets = store.assets(for: album.id)
        let toolbarMenuActions = PetAlbumDetailToolbarMenuActionResolver.actions()

        MHBScreenScrollView {
            LazyVStack(alignment: .leading, spacing: MHBTheme.Spacing.s5) {
                PetAlbumDetailHeader(
                    title: album.title,
                    subtitle: "\(album.petName) · \(album.photoCountText)"
                )

                PetAlbumMosaicGrid(
                    assets: assets,
                    onDeleteAsset: { asset in
                        pendingDeleteAsset = asset
                    }
                )
            }
            .padding(.horizontal, MHBTheme.Spacing.s5)
            .padding(.top, MHBTheme.Spacing.s3)
            .padding(.bottom, MHBTheme.Spacing.s8)
        }
        .task(id: albumID) {
            await store.loadAssets(for: albumID)
        }
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            max(geometry.contentOffset.y, 0)
        } action: { _, offset in
            updateNavigationTitleVisibility(offset)
        }
        .background(MHBTheme.ColorToken.cardSolid.color.ignoresSafeArea())
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
        .navigationTitle(isNavigationTitleVisible ? album.title : "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ForEach(toolbarMenuActions) { action in
                        Button {
                            handleToolbarMenuAction(action)
                        } label: {
                            Label {
                                Text(action.title)
                            } icon: {
                                Image(systemName: action.systemImageName)
                            }
                        }
                        .accessibilityIdentifier("petAlbum.detail.menu.\(action.id)")
                    }
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("相册操作")
                .accessibilityIdentifier("petAlbum.detail.addMenu")
            }
        }
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

    private func updateNavigationTitleVisibility(_ scrollOffset: CGFloat) {
        let showThreshold: CGFloat = MHBTheme.Spacing.s8
        let hideThreshold: CGFloat = MHBTheme.Spacing.s5
        let nextValue: Bool

        if isNavigationTitleVisible {
            nextValue = scrollOffset >= hideThreshold
        } else {
            nextValue = scrollOffset >= showThreshold
        }

        guard nextValue != isNavigationTitleVisible else {
            return
        }

        withAnimation(.easeInOut(duration: 0.22)) {
            isNavigationTitleVisible = nextValue
        }
    }

    private var disabledLocalIdentifiers: Set<String> {
        Set(store.assets(for: albumID).compactMap(\.localIdentifier))
    }

    private func handleToolbarMenuAction(_ action: PetAlbumDetailToolbarMenuAction) {
        switch action {
        case .uploadPhotos:
            isPhotoPickerPresented = true
        case .shareAlbum:
            break
        }
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
        return PetAlbumPhotoUploadDraft(media: media, localIdentifier: localIdentifier)
    }
}
