import SwiftUI

// EnvironmentValues 图片预览环境扩展
// 核心职责：
// - 向业务视图下发图片预览宿主的打开动作与注册器
// - 暴露页面当前是否处于预览态，便于根栈按规则隐藏 tabBar
extension EnvironmentValues {
    @Entry var mhbImagePreviewPresentAction: MHBImagePreviewPresentAction? = nil
    @Entry var mhbImagePreviewSourceRegistrar: MHBImagePreviewSourceRegistrar = .noop
    @Entry public var mhbImagePreviewPresenting: Bool = false
}
