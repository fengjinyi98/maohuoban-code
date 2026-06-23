import XCTest

// ProfileUserHomeIdentityDisplayTests 个人主页身份展示文案测试
// 核心职责：
// - 固化个人主页头部展示用户毛伙伴号
// - 防止用户账号号段再次被标记为 Pet ID
final class ProfileUserHomeIdentityDisplayTests: XCTestCase {
    func testUserHomeHeaderDisplaysMaohuobanIDInsteadOfPetID() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent(
                "maohuoban/maohuoban/Features/Profile/Presentation/Components/ProfileUserHomeHeaderSections.swift"
            ),
            encoding: .utf8
        )

        XCTAssertTrue(source.contains("Text(\"毛伙伴号: \\(maohuobanID)\")"))
        XCTAssertTrue(source.contains("Text(\"IP 归属地: \\(ipLocation)\")"))
        XCTAssertFalse(source.contains("Text(\"Pet ID:"))
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
            domain: "ProfileUserHomeIdentityDisplayTests",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Unable to locate repository root."]
        )
    }
}
