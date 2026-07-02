import CoreGraphics

// MHBTheme.Spacing 间距 token
// 核心职责：
// - 统一 HTML 设计稿中的 4pt 栅格间距
// - 为 SwiftUI 和 UIKit 布局提供稳定数值来源
extension MHBTheme {
    public enum Spacing {
        public static let s1: CGFloat = 4
        public static let s2: CGFloat = 8
        public static let s3: CGFloat = 12
        public static let s4: CGFloat = 16
        public static let s5: CGFloat = 20
        public static let s6: CGFloat = 24
        public static let s8: CGFloat = 32
    }
}
