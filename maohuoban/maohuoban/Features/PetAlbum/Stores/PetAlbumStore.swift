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
}
