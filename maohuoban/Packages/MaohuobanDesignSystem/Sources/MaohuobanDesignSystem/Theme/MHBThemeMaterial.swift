import SwiftUI
import UIKit

// MHBTheme.MaterialToken 材质 token
// 核心职责：
// - 统一毛玻璃卡片、底部栏和浮层的材质语义
// - 为 SwiftUI 与 UIKit 各自提供平台原生材质入口
extension MHBTheme {
    public enum MaterialToken {
        public static let cardBackground = Material.ultraThin
        public static let tabBarBackground = Material.thin

        @MainActor
        public static let uiCardBlurEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        @MainActor
        public static let uiTabBarBlurEffect = UIBlurEffect(style: .systemThinMaterial)
    }
}
