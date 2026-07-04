import XCTest
@testable import maohuoban

// MHBMediaPickerRequestTests 媒体选择请求测试
// 核心职责：
// - 固化头像等单图入口自动确认配置
// - 固化多图发布入口保留底部确认流程
@MainActor
final class MHBMediaPickerRequestTests: XCTestCase {
    func testSingleImageRequestAutoConfirmsSelection() {
        XCTAssertTrue(MHBMediaPickerRequest.singleImage.autoConfirmSingleSelection)
        XCTAssertEqual(MHBMediaPickerRequest.singleImage.maxSelectionCount, 1)
        XCTAssertEqual(MHBMediaPickerRequest.singleImage.filter, .images)
    }

    func testCustomMultiImageRequestUsesManualConfirmation() {
        let request = MHBMediaPickerRequest(maxSelectionCount: 9, filter: .images)

        XCTAssertFalse(request.autoConfirmSingleSelection)
        XCTAssertEqual(request.maxSelectionCount, 9)
        XCTAssertEqual(request.filter, .images)
    }

    func testRequestCarriesDisabledPhotoLibraryAssetIdentifiers() {
        let request = MHBMediaPickerRequest(
            maxSelectionCount: 9,
            filter: .images,
            disabledLocalIdentifiers: ["local-1", "local-2"]
        )

        XCTAssertTrue(request.disabledLocalIdentifiers.contains("local-1"))
        XCTAssertTrue(request.disabledLocalIdentifiers.contains("local-2"))
    }

    func testRequestHidesCameraEntryByDefault() {
        let request = MHBMediaPickerRequest(maxSelectionCount: 1, filter: .images)

        XCTAssertFalse(request.showsCameraEntry)
        XCTAssertFalse(MHBMediaPickerRequest.singleImage.showsCameraEntry)
    }

    func testRequestCanOptInCameraEntry() {
        let request = MHBMediaPickerRequest(
            maxSelectionCount: 1,
            filter: .images,
            showsCameraEntry: true
        )

        XCTAssertTrue(request.showsCameraEntry)
    }
}
