import Foundation

// PetAlbumMockData 宠物相册 Mock 数据
// 核心职责：
// - 为快速 UI 阶段提供稳定相册列表和详情图片
// - 模拟后端后续返回的图片尺寸与 UGC 来源关系
enum PetAlbumMockData {
    static let albums: [PetAlbumSummary] = [
        PetAlbumSummary(
            id: "gallery-1",
            title: "睡颜大赏",
            petName: "糯米",
            updatedText: "今天更新",
            photoCount: 48,
            coverImageAssetName: "HomeGalleryAlbum1"
        ),
        PetAlbumSummary(
            id: "gallery-2",
            title: "户外冒险",
            petName: "糯米",
            updatedText: "本周更新",
            photoCount: 36,
            coverImageAssetName: "HomeGalleryAlbum2",
            isPrivate: true
        ),
        PetAlbumSummary(
            id: "gallery-3",
            title: "吃货瞬间",
            petName: "糯米",
            updatedText: "创建于 2025年",
            photoCount: 28,
            coverImageAssetName: "HomeGalleryAlbum3"
        ),
        PetAlbumSummary(
            id: "album-1",
            title: "第一天带回家",
            petName: "糯米",
            updatedText: "创建于 2024年",
            photoCount: 24,
            coverImageAssetName: "HomePetAlbum1"
        ),
        PetAlbumSummary(
            id: "album-2",
            title: "在阳光下打盹",
            petName: "糯米",
            updatedText: "创建于 2025年",
            photoCount: 31,
            coverImageAssetName: "HomePetAlbum2",
            isPrivate: true
        ),
        PetAlbumSummary(
            id: "album-3",
            title: "抓蝴蝶失败",
            petName: "糯米",
            updatedText: "创建于 2025年",
            photoCount: 17,
            coverImageAssetName: "HomePetAlbum3"
        )
    ]

    static let assetsByAlbumID: [String: [PetAlbumAsset]] = {
        var result: [String: [PetAlbumAsset]] = [:]
        for (albumIndex, album) in albums.enumerated() {
            result[album.id] = makeAssets(for: album, albumIndex: albumIndex)
        }
        return result
    }()

    private static let imageAssetNames = [
        "HomeGalleryAlbum1",
        "HomeGalleryAlbum2",
        "HomeGalleryAlbum3",
        "HomePetAlbum1",
        "HomePetAlbum2",
        "HomePetAlbum3",
        "HomePetAlbum4",
        "HomePetHeroMock"
    ]

    private static let imageSizes = [
        PetAlbumImageSize(width: 1600, height: 1600),
        PetAlbumImageSize(width: 1200, height: 1600),
        PetAlbumImageSize(width: 1800, height: 1200),
        PetAlbumImageSize(width: 1440, height: 1440),
        PetAlbumImageSize(width: 1080, height: 1350),
        PetAlbumImageSize(width: 2048, height: 1365),
        PetAlbumImageSize(width: 1280, height: 1920),
        PetAlbumImageSize(width: 1920, height: 1280)
    ]

    private static func makeAssets(for album: PetAlbumSummary, albumIndex: Int) -> [PetAlbumAsset] {
        (0..<album.photoCount).map { index in
            let imageIndex = (albumIndex + index) % imageAssetNames.count
            let sizeIndex = (albumIndex * 2 + index) % imageSizes.count

            return PetAlbumAsset(
                id: "\(album.id)-asset-\(index)",
                albumID: album.id,
                imageAssetName: imageAssetNames[imageIndex],
                pixelSize: imageSizes[sizeIndex],
                source: source(for: album.id, index: index),
                caption: caption(for: index)
            )
        }
    }

    private static func source(for albumID: String, index: Int) -> PetAlbumSource {
        if index.isMultiple(of: 6) {
            return .ugcDetached(originalPostID: "post-\(albumID)-\(index)")
        }

        if index.isMultiple(of: 3) {
            return .ugcLinked(postID: "post-\(albumID)-\(index)")
        }

        return .userUpload
    }

    private static func caption(for index: Int) -> String? {
        switch index % 5 {
        case 0:
            return "午后晒太阳"
        case 1:
            return "散步路上"
        case 2:
            return "今天也很会摆拍"
        default:
            return nil
        }
    }
}
