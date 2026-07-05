import AVFoundation
import CoreGraphics

// MHBResponsiveCameraFocusConfiguration 响应式相机聚焦配置
// 核心职责：
// - 根据设备能力生成点按聚焦和曝光配置
// - 隔离相机硬件能力差异对控制器的影响
nonisolated struct MHBResponsiveCameraFocusConfiguration: Equatable {
    let focusPoint: CGPoint?
    let focusMode: AVCaptureDevice.FocusMode?
    let exposurePoint: CGPoint?
    let exposureMode: AVCaptureDevice.ExposureMode?

    static func make(
        devicePoint: CGPoint,
        isFocusPointOfInterestSupported: Bool,
        isAutoFocusSupported: Bool,
        isExposurePointOfInterestSupported: Bool,
        isAutoExposeSupported: Bool
    ) -> Self? {
        let focusMode: AVCaptureDevice.FocusMode? = if isFocusPointOfInterestSupported && isAutoFocusSupported {
            .autoFocus
        } else {
            nil
        }
        let exposureMode: AVCaptureDevice.ExposureMode? = if isExposurePointOfInterestSupported && isAutoExposeSupported {
            .autoExpose
        } else {
            nil
        }

        guard focusMode != nil || exposureMode != nil else {
            return nil
        }

        return Self(
            focusPoint: focusMode == nil ? nil : devicePoint,
            focusMode: focusMode,
            exposurePoint: exposureMode == nil ? nil : devicePoint,
            exposureMode: exposureMode
        )
    }
}
