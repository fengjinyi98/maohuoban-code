import Observation
import UIKit

// MHBPhotoLibraryPickerStore PhotoKit 选择器状态仓库
// 核心职责：
// - 管理照片库授权、相册和资源列表状态
// - 承接用户选择资源后的解析命令
@MainActor
@Observable
final class MHBPhotoLibraryPickerStore {
    let service: MHBPhotoLibraryService
    var authorizationStatus: MHBPhotoLibraryAuthorizationStatus = .notDetermined
    var albums: [MHBPhotoLibraryAlbum] = []
    var currentAlbum: MHBPhotoLibraryAlbum?
    var assets: [MHBPhotoLibraryAsset] = []
    var isLoading = false
    var isResolvingSelection = false
    var errorMessage: String?

    init(service: MHBPhotoLibraryService = MHBPhotoLibraryService()) {
        self.service = service
    }

    func load() async {
        authorizationStatus = service.authorizationStatus()
        if authorizationStatus == .notDetermined {
            authorizationStatus = await service.requestAuthorization()
        }

        guard authorizationStatus.canReadLibrary else {
            return
        }

        await loadAlbums()
    }

    func reloadCurrentAlbum() async {
        guard let currentAlbum else {
            await loadAlbums()
            return
        }
        await selectAlbum(currentAlbum)
    }

    func selectAlbum(_ album: MHBPhotoLibraryAlbum) async {
        currentAlbum = album
        isLoading = true
        defer { isLoading = false }

        assets = service.fetchAssets(from: album)
    }

    func resolveSelection(for asset: MHBPhotoLibraryAsset) async -> MHBMediaPickerResult? {
        isResolvingSelection = true
        errorMessage = nil
        defer { isResolvingSelection = false }

        let result = await service.loadSelection(for: asset)
        if result.images.isEmpty && result.livePhotos.isEmpty {
            errorMessage = "无法读取这张照片"
            return nil
        }
        return result
    }

    func cleanup() {
        service.stopCaching()
    }

    private func loadAlbums() async {
        isLoading = true
        defer { isLoading = false }

        let fetchedAlbums = service.fetchAlbums()
        albums = fetchedAlbums
        if let firstAlbum = fetchedAlbums.first {
            await selectAlbum(firstAlbum)
        } else {
            currentAlbum = nil
            assets = []
        }
    }
}
