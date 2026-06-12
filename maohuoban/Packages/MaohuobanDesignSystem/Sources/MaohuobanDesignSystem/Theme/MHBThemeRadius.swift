import CoreGraphics

// MHBTheme.Radius 圆角 token
// 核心职责：
// - 统一卡片、按钮、标签和全圆形控件的圆角等级
// - 保持 SwiftUI 与 UIKit 组件的视觉一致性
extension MHBTheme {
    public enum Radius {
        public static let small: CGFloat = 8
        public static let medium: CGFloat = 12
        public static let large: CGFloat = 16
        public static let extraLarge: CGFloat = 20
        public static let extraExtraLarge: CGFloat = 24
        public static let full: CGFloat = 9999
    }
}
