import Foundation

// ProfileCoverSource 用户主页封面图片来源
// 核心职责：
// - 统一承接远端地址和空态
// - 为个人主页封面组件提供稳定输入，对齐 MHBAvatarSource 的空态回退模式
nonisolated enum ProfileCoverSource: Equatable, Sendable {
    case remote(URL)
    case empty
}
