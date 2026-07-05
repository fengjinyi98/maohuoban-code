import AVFoundation
import CoreGraphics
import XCTest
@testable import maohuoban

// MHBResponsiveCameraFocusConfigurationTests 响应式相机聚焦配置测试
// 核心职责：
// - 固化点按预览后对焦与曝光配置
// - 固化无可用设备能力时跳过配置
@MainActor
final class MHBResponsiveCameraFocusConfigurationTests: XCTestCase {
    func testConfigurationUsesAutoFocusAndAutoExposeWhenBothCapabilitiesAreAvailable() {
        let point = CGPoint(x: 0.34, y: 0.62)

        let configuration = MHBResponsiveCameraFocusConfiguration.make(
            devicePoint: point,
            isFocusPointOfInterestSupported: true,
            isAutoFocusSupported: true,
            isExposurePointOfInterestSupported: true,
            isAutoExposeSupported: true
        )

        XCTAssertEqual(configuration?.focusPoint, point)
        XCTAssertEqual(configuration?.focusMode, .autoFocus)
        XCTAssertEqual(configuration?.exposurePoint, point)
        XCTAssertEqual(configuration?.exposureMode, .autoExpose)
    }

    func testConfigurationKeepsExposureWhenFocusCapabilityIsUnavailable() {
        let point = CGPoint(x: 0.21, y: 0.45)

        let configuration = MHBResponsiveCameraFocusConfiguration.make(
            devicePoint: point,
            isFocusPointOfInterestSupported: false,
            isAutoFocusSupported: true,
            isExposurePointOfInterestSupported: true,
            isAutoExposeSupported: true
        )

        XCTAssertNil(configuration?.focusPoint)
        XCTAssertNil(configuration?.focusMode)
        XCTAssertEqual(configuration?.exposurePoint, point)
        XCTAssertEqual(configuration?.exposureMode, .autoExpose)
    }

    func testConfigurationReturnsNilWhenNoPointOfInterestCapabilityIsAvailable() {
        let configuration = MHBResponsiveCameraFocusConfiguration.make(
            devicePoint: CGPoint(x: 0.5, y: 0.5),
            isFocusPointOfInterestSupported: false,
            isAutoFocusSupported: false,
            isExposurePointOfInterestSupported: false,
            isAutoExposeSupported: false
        )

        XCTAssertNil(configuration)
    }
}
