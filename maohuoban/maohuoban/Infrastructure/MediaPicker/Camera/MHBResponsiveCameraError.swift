import Foundation

// MHBResponsiveCameraError 相机配置错误
// 核心职责：
// - 标识基础设施内部相机配置失败原因
// - 避免把底层错误类型泄露到业务页面
enum MHBResponsiveCameraError: Error {
    case cameraUnavailable
    case configurationFailed
}
