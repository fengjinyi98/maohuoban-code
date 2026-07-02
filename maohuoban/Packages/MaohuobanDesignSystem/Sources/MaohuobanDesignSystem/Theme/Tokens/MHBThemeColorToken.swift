import SwiftUI
import UIKit

// MHBTheme.ColorToken 颜色 token
// 核心职责：
// - 统一承载 HTML 设计稿中的品牌色、语义色和中性色
// - 每个 token 同时持有亮色和暗色分量，自动适配系统 light/dark 模式
// - 同时提供 SwiftUI Color 与 UIKit UIColor 桥接
extension MHBTheme {
    public struct ColorToken: Sendable, Equatable {
        // 亮色分量
        public let hex: String
        public let red: Double
        public let green: Double
        public let blue: Double
        public let alpha: Double

        // 暗色分量
        public let darkHex: String
        public let darkRed: Double
        public let darkGreen: Double
        public let darkBlue: Double
        public let darkAlpha: Double

        /// 自适应 Color — 自动跟随系统 light/dark 切换
        public var color: Color {
            Color(
                light: Color(red: red, green: green, blue: blue, opacity: alpha),
                dark: Color(red: darkRed, green: darkGreen, blue: darkBlue, opacity: darkAlpha)
            )
        }

        /// 自适应 UIColor — 自动跟随系统 light/dark 切换
        @MainActor
        public var uiColor: UIColor {
            UIColor { traits in
                if traits.userInterfaceStyle == .dark {
                    UIColor(red: darkRed, green: darkGreen, blue: darkBlue, alpha: darkAlpha)
                } else {
                    UIColor(red: red, green: green, blue: blue, alpha: alpha)
                }
            }
        }

        public init(
            hex: String,
            red: Double, green: Double, blue: Double, alpha: Double = 1,
            darkHex: String? = nil,
            darkRed: Double? = nil, darkGreen: Double? = nil, darkBlue: Double? = nil, darkAlpha: Double? = nil
        ) {
            self.hex = hex
            self.red = red
            self.green = green
            self.blue = blue
            self.alpha = alpha
            self.darkHex = darkHex ?? hex
            self.darkRed = darkRed ?? red
            self.darkGreen = darkGreen ?? green
            self.darkBlue = darkBlue ?? blue
            self.darkAlpha = darkAlpha ?? alpha
        }

        // MARK: - 品牌色

        public static let primary = ColorToken(
            hex: "#4F8CFF",
            red: 79 / 255, green: 140 / 255, blue: 255 / 255,
            darkHex: "#5B96FF",
            darkRed: 91 / 255, darkGreen: 150 / 255, darkBlue: 255 / 255
        )
        public static let primaryLight = ColorToken(
            hex: "#6BCBFF",
            red: 107 / 255, green: 203 / 255, blue: 255 / 255,
            darkHex: "#74D1FF",
            darkRed: 116 / 255, darkGreen: 209 / 255, darkBlue: 255 / 255
        )
        public static let primaryDark = ColorToken(
            hex: "#3A6FCC",
            red: 58 / 255, green: 111 / 255, blue: 204 / 255,
            darkHex: "#4A7FDC",
            darkRed: 74 / 255, darkGreen: 127 / 255, darkBlue: 220 / 255
        )

        // MARK: - 语义色（亮暗一致）

        public static let success = ColorToken(
            hex: "#34C759", red: 52 / 255, green: 199 / 255, blue: 89 / 255
        )
        public static let warning = ColorToken(
            hex: "#FF9500", red: 255 / 255, green: 149 / 255, blue: 0 / 255
        )
        public static let danger = ColorToken(
            hex: "#FF3B30", red: 255 / 255, green: 59 / 255, blue: 48 / 255
        )
        public static let teal = ColorToken(
            hex: "#5AC8FA", red: 90 / 255, green: 200 / 255, blue: 250 / 255
        )
        public static let purple = ColorToken(
            hex: "#AF52DE", red: 175 / 255, green: 82 / 255, blue: 222 / 255
        )

        // MARK: - 背景与卡片

        public static let background = ColorToken(
            hex: "#F7F9FC",
            red: 247 / 255, green: 249 / 255, blue: 252 / 255,
            darkHex: "#000000",
            darkRed: 0, darkGreen: 0, darkBlue: 0
        )
        public static let cardSolid = ColorToken(
            hex: "#FFFFFF",
            red: 1, green: 1, blue: 1,
            darkHex: "#1C1C1E",
            darkRed: 28 / 255, darkGreen: 28 / 255, darkBlue: 30 / 255
        )
        public static let card = ColorToken(
            hex: "rgba(255,255,255,0.75)",
            red: 1, green: 1, blue: 1, alpha: 0.75,
            darkHex: "rgba(20,20,22,0.75)",
            darkRed: 20 / 255, darkGreen: 20 / 255, darkBlue: 22 / 255, darkAlpha: 0.75
        )
        public static let cardBorder = ColorToken(
            hex: "rgba(255,255,255,0.6)",
            red: 1, green: 1, blue: 1, alpha: 0.6,
            darkHex: "rgba(255,255,255,0.08)",
            darkRed: 1, darkGreen: 1, darkBlue: 1, darkAlpha: 0.08
        )

        // MARK: - 文字层级

        public static let labelPrimary = ColorToken(
            hex: "#1A1D26",
            red: 26 / 255, green: 29 / 255, blue: 38 / 255,
            darkHex: "#FFFFFF",
            darkRed: 1, darkGreen: 1, darkBlue: 1
        )
        public static let labelSecondary = ColorToken(
            hex: "#6E7681",
            red: 110 / 255, green: 118 / 255, blue: 129 / 255,
            darkHex: "#98989D",
            darkRed: 152 / 255, darkGreen: 152 / 255, darkBlue: 157 / 255
        )
        public static let labelTertiary = ColorToken(
            hex: "#9CA3AF",
            red: 156 / 255, green: 163 / 255, blue: 175 / 255,
            darkHex: "#6E6E73",
            darkRed: 110 / 255, darkGreen: 110 / 255, darkBlue: 115 / 255
        )
        public static let labelQuaternary = ColorToken(
            hex: "#D1D5DB",
            red: 209 / 255, green: 213 / 255, blue: 219 / 255,
            darkHex: "#3A3A3C",
            darkRed: 58 / 255, darkGreen: 58 / 255, darkBlue: 60 / 255
        )

        // MARK: - 主色透明背景

        public static let primaryBackground = ColorToken(
            hex: "rgba(79,140,255,0.08)",
            red: 79 / 255, green: 140 / 255, blue: 255 / 255, alpha: 0.08,
            darkHex: "rgba(79,140,255,0.14)",
            darkRed: 79 / 255, darkGreen: 140 / 255, darkBlue: 255 / 255, darkAlpha: 0.14
        )
        public static let primaryBackgroundSoft = ColorToken(
            hex: "rgba(79,140,255,0.04)",
            red: 79 / 255, green: 140 / 255, blue: 255 / 255, alpha: 0.04,
            darkHex: "rgba(79,140,255,0.07)",
            darkRed: 79 / 255, darkGreen: 140 / 255, darkBlue: 255 / 255, darkAlpha: 0.07
        )

        // MARK: - 分割线

        public static let separator = ColorToken(
            hex: "rgba(0,0,0,0.05)",
            red: 0, green: 0, blue: 0, alpha: 0.05,
            darkHex: "rgba(255,255,255,0.08)",
            darkRed: 1, darkGreen: 1, darkBlue: 1, darkAlpha: 0.08
        )
        public static let separatorSoft = ColorToken(
            hex: "rgba(0,0,0,0.03)",
            red: 0, green: 0, blue: 0, alpha: 0.03,
            darkHex: "rgba(255,255,255,0.04)",
            darkRed: 1, darkGreen: 1, darkBlue: 1, darkAlpha: 0.04
        )

        // MARK: - Toast

        public static let toastBackground = ColorToken(
            hex: "#1C1C1E",
            red: 28 / 255, green: 28 / 255, blue: 30 / 255,
            darkHex: "#2C2C2E",
            darkRed: 44 / 255, darkGreen: 44 / 255, darkBlue: 46 / 255
        )
        public static let toastBorder = ColorToken(
            hex: "rgba(255,255,255,0.08)",
            red: 1, green: 1, blue: 1, alpha: 0.08,
            darkHex: "rgba(255,255,255,0.12)",
            darkRed: 1, darkGreen: 1, darkBlue: 1, darkAlpha: 0.12
        )
    }
}
