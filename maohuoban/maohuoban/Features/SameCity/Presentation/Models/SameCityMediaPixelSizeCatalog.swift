import CoreGraphics

// SameCityMediaPixelSizeCatalog 同城本地媒资尺寸目录
// 核心职责：
// - 为开发期本地样例媒资补齐后端图片元数据
// - 保证图片预览 Hero 动画使用真实媒资比例
enum SameCityMediaPixelSizeCatalog {
    static func pixelSize(for assetName: String) -> CGSize? {
        switch assetName {
        case "HomePetHeroMock":
            CGSize(width: 2717, height: 4076)
        case "HomeGalleryAlbum1",
             "HomeGalleryAlbum2",
             "HomeGalleryAlbum3",
             "HomePetAlbum1",
             "HomePetAlbum2",
             "HomePetAlbum3",
             "HomePetAlbum4":
            CGSize(width: 1024, height: 1024)
        default:
            nil
        }
    }
}
