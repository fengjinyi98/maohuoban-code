import CoreGraphics

// MHBTheme.IconSize 图标尺寸 token
// 核心职责：
// - 统一跨 Feature 复用的图标尺寸基准
// - 避免业务视图直接硬编码固定图标字号
extension MHBTheme {
    public enum IconSize {
        public static let tabRootPlaceholder: CGFloat = 48
    }
}
