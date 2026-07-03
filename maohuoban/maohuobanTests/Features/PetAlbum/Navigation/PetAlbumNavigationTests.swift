import XCTest
@testable import maohuoban

// PetAlbumNavigationTests 宠物相册导航测试
// 核心职责：
// - 固化相册模块只产出导航意图的边界
// - 防止相册流程重新在子页面注册独立导航目标
final class PetAlbumNavigationTests: XCTestCase {
    @MainActor
    func testHomeAndProfileRoutesCarryPetAlbumDestination() {
        let context = PetAlbumEntryContext(
            petID: "pet-1",
            petName: "糯米"
        )
        let album = PetAlbumSummary(
            id: "album-1",
            title: "糯米成长",
            petName: "全部宠物",
            updatedText: "刚刚更新",
            photoCount: 3,
            coverImageAssetName: "HomeGalleryAlbum1"
        )
        let destination = PetAlbumRouteDestination.detail(album)

        XCTAssertEqual(
            HomeRoute.petAlbumDestination(context: context, destination: destination),
            .petAlbumDestination(context: context, destination: destination)
        )
        XCTAssertEqual(
            ProfileRoute.petAlbumDestination(context: context, destination: destination),
            .petAlbumDestination(context: context, destination: destination)
        )
        XCTAssertEqual(destination.initialAlbums, [album])
    }

    func testPetAlbumRootDoesNotRegisterNestedNavigationDestination() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent(
                "maohuoban/maohuoban/Features/PetAlbum/Presentation/Navigation/PetAlbumRootScreen.swift"
            ),
            encoding: .utf8
        )

        XCTAssertFalse(source.contains("navigationDestination(for: PetAlbumRoute.self)"))
        XCTAssertTrue(source.contains("onOpenRoute"))
    }

    func testPetAlbumListUsesExplicitRouteCallback() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent(
                "maohuoban/maohuoban/Features/PetAlbum/Presentation/PetAlbumListScreen.swift"
            ),
            encoding: .utf8
        )

        XCTAssertTrue(source.contains("onOpenRoute(createRoute)"))
        XCTAssertFalse(source.contains("NavigationLink(value: createRoute)"))
    }

    private static func repositoryRoot() throws -> URL {
        var url = URL(fileURLWithPath: #filePath)
        while url.pathComponents.isEmpty == false {
            let candidate = url.appendingPathComponent("maohuoban/maohuoban.xcodeproj")
            if FileManager.default.fileExists(atPath: candidate.path) {
                return url
            }
            url.deleteLastPathComponent()
        }
        throw NSError(
            domain: "PetAlbumNavigationTests",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Unable to locate repository root."]
        )
    }
}
