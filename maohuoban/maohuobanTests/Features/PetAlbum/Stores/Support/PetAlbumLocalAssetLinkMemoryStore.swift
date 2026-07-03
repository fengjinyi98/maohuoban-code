import Foundation
@testable import maohuoban

// PetAlbumLocalAssetLinkMemoryStore 相册本机映射内存测试存储
// 核心职责：
// - 为 Store 单元测试提供可观测的本机映射读写实现
// - 避免测试污染真实 UserDefaults
final class PetAlbumLocalAssetLinkMemoryStore: PetAlbumLocalAssetLinkStore {
    private var storedLinks: [PetAlbumLocalAssetLink] = []

    func appendWithoutDeduplication(_ link: PetAlbumLocalAssetLink) {
        storedLinks.append(link)
    }

    func links(userID: String, albumID: String) -> [PetAlbumLocalAssetLink] {
        storedLinks.filter { link in
            link.userID == userID && link.albumID == albumID
        }
    }

    func upsert(_ link: PetAlbumLocalAssetLink) {
        storedLinks.removeAll { existing in
            existing.userID == link.userID
                && existing.albumID == link.albumID
                && (
                    existing.serverAssetID == link.serverAssetID
                        || existing.localIdentifier == link.localIdentifier
                )
        }
        storedLinks.append(link)
    }

    func remove(userID: String, albumID: String, serverAssetID: String) {
        storedLinks.removeAll { link in
            link.userID == userID
                && link.albumID == albumID
                && link.serverAssetID == serverAssetID
        }
    }

    func removeAlbum(userID: String, albumID: String) {
        storedLinks.removeAll { link in
            link.userID == userID && link.albumID == albumID
        }
    }
}
