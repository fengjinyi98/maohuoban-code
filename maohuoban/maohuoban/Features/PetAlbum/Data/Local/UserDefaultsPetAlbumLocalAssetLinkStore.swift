import Foundation

// UserDefaultsPetAlbumLocalAssetLinkStore UserDefaults 相册本机映射存储
// 核心职责：
// - 使用轻量 JSON 元数据保存本机照片映射
// - 避免保存图片、缩略图或其他大体积二进制内容
final class UserDefaultsPetAlbumLocalAssetLinkStore: PetAlbumLocalAssetLinkStore {
    private let userDefaults: UserDefaults
    private let key = "maohuoban.petAlbum.localAssetLinks.v1"
    private let maxLinkCount = 50_000

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func links(userID: String, albumID: String) -> [PetAlbumLocalAssetLink] {
        allLinks().filter { link in
            link.userID == userID && link.albumID == albumID
        }
    }

    func upsert(_ link: PetAlbumLocalAssetLink) {
        var links = allLinks()
        links.removeAll { existing in
            existing.userID == link.userID
                && existing.albumID == link.albumID
                && (
                    existing.serverAssetID == link.serverAssetID
                        || existing.localIdentifier == link.localIdentifier
                )
        }
        links.append(link)
        persist(trimmed(links))
    }

    func remove(userID: String, albumID: String, serverAssetID: String) {
        var links = allLinks()
        links.removeAll { link in
            link.userID == userID
                && link.albumID == albumID
                && link.serverAssetID == serverAssetID
        }
        persist(links)
    }

    func removeAlbum(userID: String, albumID: String) {
        var links = allLinks()
        links.removeAll { link in
            link.userID == userID && link.albumID == albumID
        }
        persist(links)
    }

    private func allLinks() -> [PetAlbumLocalAssetLink] {
        guard let data = userDefaults.data(forKey: key) else {
            return []
        }
        return (try? JSONDecoder().decode([PetAlbumLocalAssetLink].self, from: data)) ?? []
    }

    private func persist(_ links: [PetAlbumLocalAssetLink]) {
        guard let data = try? JSONEncoder().encode(links) else {
            return
        }
        userDefaults.set(data, forKey: key)
    }

    private func trimmed(_ links: [PetAlbumLocalAssetLink]) -> [PetAlbumLocalAssetLink] {
        guard links.count > maxLinkCount else {
            return links
        }
        return Array(
            links
                .sorted { $0.createdAt > $1.createdAt }
                .prefix(maxLinkCount)
        )
    }
}
