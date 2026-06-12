import SwiftUI
import UIKit

// MHBTheme.ColorToken 颜色 token
// 核心职责：
// - 统一承载 HTML 设计稿中的品牌色、语义色和中性色
// - 同时提供 SwiftUI Color 与 UIKit UIColor 桥接
extension MHBTheme {
    public struct ColorToken: Sendable, Equatable {
        public let hex: String
        public let red: Double
        public let green: Double
        public let blue: Double
        public let alpha: Double

        public var color: Color {
            Color(red: red, green: green, blue: blue, opacity: alpha)
        }

        @MainActor
        public var uiColor: UIColor {
            UIColor(red: red, green: green, blue: blue, alpha: alpha)
        }

        public init(hex: String, red: Double, green: Double, blue: Double, alpha: Double = 1) {
            self.hex = hex
            self.red = red
            self.green = green
            self.blue = blue
            self.alpha = alpha
        }

        public static let primary = ColorToken(hex: "#4F8CFF", red: 79 / 255, green: 140 / 255, blue: 255 / 255)
        public static let primaryLight = ColorToken(hex: "#6BCBFF", red: 107 / 255, green: 203 / 255, blue: 255 / 255)
        public static let primaryDark = ColorToken(hex: "#3A6FCC", red: 58 / 255, green: 111 / 255, blue: 204 / 255)

        public static let success = ColorToken(hex: "#34C759", red: 52 / 255, green: 199 / 255, blue: 89 / 255)
        public static let warning = ColorToken(hex: "#FF9500", red: 255 / 255, green: 149 / 255, blue: 0 / 255)
        public static let danger = ColorToken(hex: "#FF3B30", red: 255 / 255, green: 59 / 255, blue: 48 / 255)
        public static let teal = ColorToken(hex: "#5AC8FA", red: 90 / 255, green: 200 / 255, blue: 250 / 255)
        public static let purple = ColorToken(hex: "#AF52DE", red: 175 / 255, green: 82 / 255, blue: 222 / 255)

        public static let background = ColorToken(hex: "#F7F9FC", red: 247 / 255, green: 249 / 255, blue: 252 / 255)
        public static let cardSolid = ColorToken(hex: "#FFFFFF", red: 1, green: 1, blue: 1)

        public static let labelPrimary = ColorToken(hex: "#1A1D26", red: 26 / 255, green: 29 / 255, blue: 38 / 255)
        public static let labelSecondary = ColorToken(hex: "#6E7681", red: 110 / 255, green: 118 / 255, blue: 129 / 255)
        public static let labelTertiary = ColorToken(hex: "#9CA3AF", red: 156 / 255, green: 163 / 255, blue: 175 / 255)
        public static let labelQuaternary = ColorToken(hex: "#D1D5DB", red: 209 / 255, green: 213 / 255, blue: 219 / 255)

        public static let primaryBackground = ColorToken(hex: "rgba(79,140,255,0.08)", red: 79 / 255, green: 140 / 255, blue: 255 / 255, alpha: 0.08)
        public static let primaryBackgroundSoft = ColorToken(hex: "rgba(79,140,255,0.04)", red: 79 / 255, green: 140 / 255, blue: 255 / 255, alpha: 0.04)
        public static let card = ColorToken(hex: "rgba(255,255,255,0.75)", red: 1, green: 1, blue: 1, alpha: 0.75)
        public static let cardBorder = ColorToken(hex: "rgba(255,255,255,0.6)", red: 1, green: 1, blue: 1, alpha: 0.6)
        public static let glass = ColorToken(hex: "rgba(255,255,255,0.6)", red: 1, green: 1, blue: 1, alpha: 0.6)
        public static let separator = ColorToken(hex: "rgba(0,0,0,0.05)", red: 0, green: 0, blue: 0, alpha: 0.05)
        public static let separatorSoft = ColorToken(hex: "rgba(0,0,0,0.03)", red: 0, green: 0, blue: 0, alpha: 0.03)
    }
}
