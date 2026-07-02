import XCTest
@testable import maohuoban

// CurrentUserStoreTests 当前用户单一数据源测试
// 核心职责：
// - 固化登录响应写入当前用户 Store 的单向数据流
// - 约束我的页资料概览从同一个 Store 派生
@MainActor
class CurrentUserStoreTests: XCTestCase {
    static func authSession(
        displayName: String,
        maohuobanID: String,
        hasPassword: Bool = false
    ) -> AuthSession {
        AuthSession(
            accessToken: "access-token",
            refreshToken: "refresh-token",
            tokenType: "Bearer",
            expiresInSeconds: 900,
            refreshExpiresInSeconds: 15_552_000,
            user: AuthUser(
                id: "user-1",
                phone: "13800138010",
                phoneMasked: "138****8010",
                hasPassword: hasPassword,
                profile: CurrentUserProfileSummary(
                    maohuobanID: maohuobanID,
                    displayName: displayName,
                    avatar: nil,
                    avatarPresentation: CurrentUserAvatarPresentation(
                        sex: .female,
                        sexVisibility: .visible
                    )
                )
            )
        )
    }

    static func source(appRelativePath: String) throws -> String {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let projectRoot = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceURL = projectRoot
            .appendingPathComponent("maohuoban")
            .appendingPathComponent(appRelativePath)
        return try String(contentsOf: sourceURL, encoding: .utf8)
    }

    static func condensed(_ source: String) -> String {
        source.filter { $0.isWhitespace == false }
    }
}
