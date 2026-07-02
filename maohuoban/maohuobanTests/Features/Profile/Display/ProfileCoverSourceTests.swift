import XCTest
@testable import maohuoban

// ProfileCoverSourceTests 用户主页封面来源测试
// 核心职责：
// - 固化封面来源在无远端地址时回退到空态
// - 验证远端地址正确解析为 .remote
// - 对齐头像 avatarSource 空态回退行为
@MainActor
final class ProfileCoverSourceTests: XCTestCase {
    func testCoverSourceReturnsEmptyWhenNoCoverURL() {
        let store = CurrentUserStore()
        XCTAssertEqual(store.coverSource, .empty)
    }

    func testCoverSourceReturnsEmptyWhenCoverURLIsNil() {
        let store = CurrentUserStore()
        store.coverURLString = nil
        XCTAssertEqual(store.coverSource, .empty)
    }

    func testCoverSourceReturnsEmptyWhenCoverURLIsWhitespace() {
        let store = CurrentUserStore()
        store.coverURLString = "   "
        XCTAssertEqual(store.coverSource, .empty)
    }

    func testCoverSourceReturnsRemoteWhenCoverURLIsAppRelativePath() {
        let store = CurrentUserStore()
        store.coverURLString = "/api/v1/media/assets/cover-uuid/content"
        let expectedURL = MHBBackendEndpoint.resolve("/api/v1/media/assets/cover-uuid/content")
        XCTAssertEqual(store.coverSource, .remote(expectedURL!))
    }

    func testCoverSourceReturnsRemoteWhenCoverURLIsHTTPS() {
        let store = CurrentUserStore()
        let urlString = "https://cdn.example.com/cover.png"
        store.coverURLString = urlString
        let expectedURL = URL(string: urlString)!
        XCTAssertEqual(store.coverSource, .remote(expectedURL))
    }

    func testClearResetsCoverSourceToEmpty() {
        let store = CurrentUserStore()
        store.coverURLString = "/api/v1/media/assets/cover-uuid/content"

        store.clear()

        XCTAssertEqual(store.coverSource, .empty)
    }
}
