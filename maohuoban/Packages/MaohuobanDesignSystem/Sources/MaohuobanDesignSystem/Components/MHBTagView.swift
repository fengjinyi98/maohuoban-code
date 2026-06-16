import SwiftUI

// MHBTagView 统一标签组件
// 核心职责：
// - 承载各种类型标签（如同城、同窝关系、体重变化、系统配置等）的 UI 呈现
// - 统一标签的圆角等级 (MHBTheme.Radius.small)、字体级别 (MHBTheme.Typography.section / caption)
// - 提供高度一致的视觉风格与可定制的自适应配色
public struct MHBTagView<Icon: View>: View {
    public enum Style: Sendable, Equatable {
        case primary      // 品牌蓝
        case success      // 成功绿
        case warning      // 警告橙
        case danger       // 危险红
        case purple       // 优雅紫
        case neutral      // 中性灰
        case whiteTranslucent // 白色半透明
        case custom(foreground: Color, background: Color)
        
        public var colors: (foreground: Color, background: Color) {
            switch self {
            case .primary:
                return (
                    Color(light: Color(hexString: "#1D4ED8"), dark: Color(hexString: "#5B96FF")),
                    Color(light: Color(hexString: "#DBEAFE"), dark: Color(hexString: "#4F8CFF").opacity(0.16))
                )
            case .success:
                return (
                    Color(light: Color(hexString: "#047857"), dark: Color(hexString: "#34C759")),
                    Color(light: Color(hexString: "#D1FAE5"), dark: Color(hexString: "#34C759").opacity(0.16))
                )
            case .warning:
                return (
                    Color(light: Color(hexString: "#B45309"), dark: Color(hexString: "#FF9500")),
                    Color(light: Color(hexString: "#FEF3C7"), dark: Color(hexString: "#FF9500").opacity(0.16))
                )
            case .danger:
                return (
                    Color(light: Color(hexString: "#B91C1C"), dark: Color(hexString: "#FF3B30")),
                    Color(light: Color(hexString: "#FEE2E2"), dark: Color(hexString: "#FF3B30").opacity(0.16))
                )
            case .purple:
                return (
                    Color(light: Color(hexString: "#6D28D9"), dark: Color(hexString: "#AF52DE")),
                    Color(light: Color(hexString: "#F3E8FF"), dark: Color(hexString: "#AF52DE").opacity(0.16))
                )
            case .neutral:
                return (
                    Color(light: Color(hexString: "#4B5563"), dark: Color(hexString: "#98989D")),
                    Color(light: Color(hexString: "#F3F4F6"), dark: Color(hexString: "#98989D").opacity(0.16))
                )
            case .whiteTranslucent:
                return (
                    .white.opacity(0.6),
                    .white.opacity(0.08)
                )
            case .custom(let foreground, let background):
                return (foreground, background)
            }
        }
    }

    public enum Size: Sendable, Equatable {
        case small        // font size 11, vertical padding 3, horizontal padding 8
        case medium       // font size 12, vertical padding 4, horizontal padding 10
        
        public var font: Font {
            switch self {
            case .small:
                return MHBTheme.Typography.section
            case .medium:
                return MHBTheme.Typography.caption
            }
        }
        
        public var verticalPadding: CGFloat {
            switch self {
            case .small:
                return 3
            case .medium:
                return 4
            }
        }
        
        public var horizontalPadding: CGFloat {
            switch self {
            case .small:
                return 8
            case .medium:
                return 10
            }
        }
        
        public var iconSpacing: CGFloat {
            return 4
        }
    }

    private let title: String
    private let icon: Icon?
    private let style: Style
    private let size: Size
    private let cornerRadius: CGFloat

    /// 支持自定义 Icon View 的初始化函数
    public init(
        _ title: String,
        style: Style = .primary,
        size: Size = .small,
        cornerRadius: CGFloat = MHBTheme.Radius.small,
        @ViewBuilder icon: () -> Icon
    ) {
        self.title = title
        self.icon = icon()
        self.style = style
        self.size = size
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        let colors = style.colors
        HStack(spacing: size.iconSpacing) {
            if let icon = icon {
                icon
            }
            Text(title)
        }
        .font(size.font)
        .foregroundStyle(colors.foreground)
        .padding(.vertical, size.verticalPadding)
        .padding(.horizontal, size.horizontalPadding)
        .background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(colors.background)
        }
    }
}

// MARK: - 便利初始化扩展

extension MHBTagView where Icon == EmptyView {
    /// 无图标标签的便利初始化函数
    public init(
        _ title: String,
        style: Style = .primary,
        size: Size = .small,
        cornerRadius: CGFloat = MHBTheme.Radius.small
    ) {
        self.title = title
        self.icon = nil
        self.style = style
        self.size = size
        self.cornerRadius = cornerRadius
    }
}

extension MHBTagView where Icon == Image {
    /// SF Symbols 图标标签的便利初始化函数
    public init(
        _ title: String,
        systemImage: String,
        style: Style = .primary,
        size: Size = .small,
        cornerRadius: CGFloat = MHBTheme.Radius.small
    ) {
        self.title = title
        self.icon = Image(systemName: systemImage)
        self.style = style
        self.size = size
        self.cornerRadius = cornerRadius
    }
}

// MARK: - 颜色解析助手

fileprivate extension Color {
    init(hexString: String) {
        let hex = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 3:
            (r, g, b) = ((int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255.0, green: Double(g) / 255.0, blue: Double(b) / 255.0)
    }
}
