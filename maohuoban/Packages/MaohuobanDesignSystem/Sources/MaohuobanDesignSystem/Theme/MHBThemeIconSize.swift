import CoreGraphics

// MHBTheme.IconSize 图标尺寸 token
// 核心职责：
// - 统一跨 Feature 复用的图标尺寸基准
// - 避免业务视图直接硬编码固定图标字号
extension MHBTheme {
    public enum IconSize {
        public static let small: CGFloat = 16
        public static let medium: CGFloat = 20
        public static let large: CGFloat = 28
        public static let avatar: CGFloat = 56
        public static let tabRootPlaceholder: CGFloat = 48
    }
}
