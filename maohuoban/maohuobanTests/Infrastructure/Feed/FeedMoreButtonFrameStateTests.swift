import CoreGraphics
import XCTest
@testable import maohuoban

// FeedMoreButtonFrameStateTests Feed 更多按钮 frame 状态测试
// 核心职责：
// - 固化相同 frame 输入不会重复写入 SwiftUI 状态
// - 保留 frame 变化时更新浮层锚点的行为
@MainActor
final class FeedMoreButtonFrameStateTests: XCTestCase {
    func testResolvedUpdateReturnsNilForEquivalentFrames() {
        let frames = [
            "post-1": CGRect(x: 10, y: 20, width: 32, height: 32)
        ]

        let update = FeedMoreButtonFrameStateResolver.resolvedUpdate(
            current: frames,
            incoming: frames
        )

        XCTAssertNil(update)
    }

    func testResolvedUpdateReturnsIncomingFramesWhenAnchorChanges() {
        let current = [
            "post-1": CGRect(x: 10, y: 20, width: 32, height: 32)
        ]
        let incoming = [
            "post-1": CGRect(x: 10, y: 24, width: 32, height: 32)
        ]

        let update = FeedMoreButtonFrameStateResolver.resolvedUpdate(
            current: current,
            incoming: incoming
        )

        XCTAssertEqual(update, incoming)
    }
}
