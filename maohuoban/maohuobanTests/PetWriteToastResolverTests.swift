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
            successMessage: "宠物档案已创建",
            derivativeMessage: nil
        )

        XCTAssertEqual(events, [.success("宠物档案已创建")])
    }

    func testCreatedPetWithPartialMediaShowsWarning() {
        let events = PetWriteToastResolver.events(
            phase: .createdPetWithPartialMedia("pet-1"),
            successMessage: "档案已创建，部分媒体保存失败",
            derivativeMessage: nil
        )

        XCTAssertEqual(events, [.warning("档案已创建，部分媒体保存失败")])
    }

    func testFailedShowsDanger() {
        let events = PetWriteToastResolver.events(
            phase: .failed("请先登录"),
            successMessage: nil,
            derivativeMessage: nil
        )

        XCTAssertEqual(events, [.danger("请先登录")])
    }

    func testDerivativeMessageIsHiddenAfterSuccess() {
        let events = PetWriteToastResolver.events(
            phase: .uploadedBackground("asset-1"),
            successMessage: "宠物背景已上传",
            derivativeMessage: "派生资源处理中"
        )

        XCTAssertEqual(events, [.success("宠物背景已上传")])
    }
}
