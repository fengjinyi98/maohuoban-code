import XCTest
@testable import maohuoban

// PetAlbumLocalAssetLinkStoreTests 相册本机映射存储测试
// 核心职责：
// - 验证本机映射只按用户和相册返回轻量元数据
// - 固化相同服务端资产或本机照片重复写入时的覆盖规则
final class PetAlbumLocalAssetLinkStoreTests: XCTestCase {
    @MainActor
    func testUserDefaultsStorePersistsLinksByUserAndAlbum() {
        let suiteName = "PetAlbumLocalAssetLinkStoreTests-\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        let store = UserDefaultsPetAlbumLocalAssetLinkStore(userDefaults: userDefaults)

        store.upsert(Self.link(userID: "user-1", albumID: "album-1", serverAssetID: "asset-1", localIdentifier: "local-1"))
        store.upsert(Self.link(userID: "user-1", albumID: "album-2", serverAssetID: "asset-2", localIdentifier: "local-2"))
        store.upsert(Self.link(userID: "user-2", albumID: "album-1", serverAssetID: "asset-3", localIdentifier: "local-3"))

        XCTAssertEqual(store.links(userID: "user-1", albumID: "album-1").map(\.localIdentifier), ["local-1"])
        XCTAssertEqual(
            UserDefaultsPetAlbumLocalAssetLinkStore(userDefaults: userDefaults)
                .links(userID: "user-1", albumID: "album-1")
                .map(\.serverAssetID),
            ["asset-1"]
        )
    }

    @MainActor
    func testUpsertReplacesSameServerAssetOrLocalIdentifier() {
        let suiteName = "PetAlbumLocalAssetLinkStoreTests-\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        let store = UserDefaultsPetAlbumLocalAssetLinkStore(userDefaults: userDefaults)

        store.upsert(Self.link(userID: "user-1", albumID: "album-1", serverAssetID: "asset-1", localIdentifier: "local-1"))
        store.upsert(Self.link(userID: "user-1", albumID: "album-1", serverAssetID: "asset-1", localIdentifier: "local-1-new"))
        store.upsert(Self.link(userID: "user-1", albumID: "album-1", serverAssetID: "asset-2", localIdentifier: "local-1-new"))

        let links = store.links(userID: "user-1", albumID: "album-1")
        XCTAssertEqual(links.map(\.serverAssetID), ["asset-2"])
        XCTAssertEqual(links.map(\.localIdentifier), ["local-1-new"])
    }

    private static func link(
        userID: String,
        albumID: String,
        serverAssetID: String,
        localIdentifier: String
    ) -> PetAlbumLocalAssetLink {
        PetAlbumLocalAssetLink(
            userID: userID,
            albumID: albumID,
            serverAssetID: serverAssetID,
            localIdentifier: localIdentifier,
            fingerprint: "sha-\(serverAssetID)",
            createdAt: Date(timeIntervalSince1970: 1)
        )
    }
}
