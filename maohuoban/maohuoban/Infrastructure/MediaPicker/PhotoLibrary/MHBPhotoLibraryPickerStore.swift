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
    let request: MHBMediaPickerRequest
    var authorizationStatus: MHBPhotoLibraryAuthorizationStatus = .notDetermined
    var albums: [MHBPhotoLibraryAlbum] = []
    var currentAlbum: MHBPhotoLibraryAlbum?
    var assets: [MHBPhotoLibraryAsset] = []
    var selectedAssets: [MHBPhotoLibraryAsset] = []
    var isLoading = false
    var isResolvingSelection = false
    var errorMessage: String?

    var hasSelection: Bool {
        !selectedAssets.isEmpty
    }

    var selectedCountText: String {
        "\(selectedAssets.count)/\(request.maxSelectionCount)"
    }

    var selectedAssetIDMap: [String: Int] {
        Dictionary(
            uniqueKeysWithValues: selectedAssets.enumerated().map { index, asset in
                (asset.id, index + 1)
            }
        )
    }

    init(
        request: MHBMediaPickerRequest = .singleImage,
        service: MHBPhotoLibraryService = MHBPhotoLibraryService()
    ) {
        self.request = request
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

        assets = service.fetchAssets(from: album, filter: request.filter)
    }

    func selectionIndex(for asset: MHBPhotoLibraryAsset) -> Int? {
        selectedAssets.firstIndex(where: { $0.id == asset.id }).map { $0 + 1 }
    }

    func toggleSelection(for asset: MHBPhotoLibraryAsset) {
        if let index = selectedAssets.firstIndex(where: { $0.id == asset.id }) {
            selectedAssets.remove(at: index)
            return
        }

        guard selectedAssets.count < request.maxSelectionCount else {
            errorMessage = "最多只能选择 \(request.maxSelectionCount) 个媒体"
            return
        }

        selectedAssets.append(asset)
    }

    func resolveSelection(for asset: MHBPhotoLibraryAsset) async -> MHBMediaPickerResult? {
        isResolvingSelection = true
        errorMessage = nil
        defer { isResolvingSelection = false }

        let result = await service.loadSelection(for: asset)
        if result.isEmpty {
            errorMessage = "无法读取这个媒体"
            return nil
        }
        return result
    }

    func resolveSelectedAssets() async -> MHBMediaPickerResult? {
        guard !selectedAssets.isEmpty else {
            return nil
        }

        isResolvingSelection = true
        errorMessage = nil
        defer { isResolvingSelection = false }

        var results: [MHBMediaPickerResult] = []
        for asset in selectedAssets {
            let result = await service.loadSelection(for: asset)
            if !result.isEmpty {
                results.append(result)
            }
        }

        let mergedResult = MHBMediaPickerResult.merging(results)
        if mergedResult.isEmpty {
            errorMessage = "无法读取选择的媒体"
            return nil
        }
        return mergedResult
    }

    func cleanup() {
        service.stopCaching()
    }

    private func loadAlbums() async {
        isLoading = true
        defer { isLoading = false }

        let fetchedAlbums = service.fetchAlbums(filter: request.filter)
        albums = fetchedAlbums
        if let firstAlbum = fetchedAlbums.first {
            await selectAlbum(firstAlbum)
        } else {
            currentAlbum = nil
            assets = []
        }
    }
}
