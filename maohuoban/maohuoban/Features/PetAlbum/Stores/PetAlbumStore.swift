import Foundation
import Observation

// PetAlbumStore 宠物相册展示状态
// 核心职责：
// - 为相册列表和详情页提供快速 UI 阶段的 Mock 数据
// - 保持相册摘要与详情图片读取入口稳定
@MainActor
@Observable
final class PetAlbumStore {
    private(set) var albums: [PetAlbumSummary]
    private(set) var assetsByAlbumID: [String: [PetAlbumAsset]]

    init(
        albums: [PetAlbumSummary] = PetAlbumMockData.albums,
        assetsByAlbumID: [String: [PetAlbumAsset]] = PetAlbumMockData.assetsByAlbumID
    ) {
        self.albums = albums
        self.assetsByAlbumID = assetsByAlbumID
    }

    func album(id: String) -> PetAlbumSummary? {
        albums.first { $0.id == id }
    }

    func assets(for albumID: String) -> [PetAlbumAsset] {
        assetsByAlbumID[albumID] ?? []
    }

    func deleteAlbum(id albumID: String) {
        albums.removeAll { $0.id == albumID }
        assetsByAlbumID[albumID] = nil
    }

    func deleteAsset(id assetID: String, in albumID: String) {
        guard var assets = assetsByAlbumID[albumID] else {
            return
        }

        assets.removeAll { $0.id == assetID }
        assetsByAlbumID[albumID] = assets
        updateAlbum(albumID: albumID) { album in
            album.replacing(photoCount: assets.count)
        }
    }

    func togglePinned(albumID: String) {
        updateAlbum(albumID: albumID) { album in
            album.replacing(isPinned: !album.isPinned)
        }
    }

    private func updateAlbum(
        albumID: String,
        transform: (PetAlbumSummary) -> PetAlbumSummary
    ) {
        guard let index = albums.firstIndex(where: { $0.id == albumID }) else {
            return
        }

        albums[index] = transform(albums[index])
    }
}
