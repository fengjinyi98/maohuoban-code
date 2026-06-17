import XCTest
@testable import maohuoban

// PetWriteToastResolverTests 宠物写入 Toast 映射测试
// 核心职责：
// - 固化写入阶段到 Toast 类型和文案的映射
// - 防止页面桥接层散落重复判断
@MainActor
final class PetWriteToastResolverTests: XCTestCase {
    func testCreatedPetWithoutMediaShowsCreatedSuccess() {
        let events = PetWriteToastResolver.events(
            phase: .createdPet("pet-1"),
            successMessage: "宠物档案已创建"
        )

        XCTAssertEqual(events, [.success("宠物档案已创建")])
    }

    func testFailedShowsDanger() {
        let events = PetWriteToastResolver.events(
            phase: .failed("请先登录"),
            successMessage: nil
        )

        XCTAssertEqual(events, [.danger("请先登录")])
    }

    func testDerivativeMessageIsHiddenAfterSuccess() {
        let events = PetWriteToastResolver.events(
            phase: .updatedPet("pet-1"),
            successMessage: "宠物档案已更新"
        )

        XCTAssertEqual(events, [.success("宠物档案已更新")])
    }
}
