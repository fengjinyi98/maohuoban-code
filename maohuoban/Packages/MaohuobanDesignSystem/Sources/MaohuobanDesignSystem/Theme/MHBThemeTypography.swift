import SwiftUI
import UIKit

// MHBTheme.Typography 字体 token
// 核心职责：
// - 统一首页、卡片、列表和标签的字号与字重
// - 使用系统字体保持动态字体和平台适配能力
extension MHBTheme {
    public enum Typography {
        public static let largeTitle = Font.system(size: 28, weight: .bold)
        public static let title = Font.system(size: 22, weight: .bold)
        public static let headline = Font.system(size: 17, weight: .semibold)
        public static let body = Font.system(size: 15, weight: .regular)
        public static let callout = Font.system(size: 14, weight: .regular)
        public static let footnote = Font.system(size: 13, weight: .regular)
        public static let caption = Font.system(size: 12, weight: .regular)
        public static let section = Font.system(size: 11, weight: .medium)

        @MainActor
        public static let uiLargeTitle = UIFont.systemFont(ofSize: 28, weight: .bold)
        @MainActor
        public static let uiTitle = UIFont.systemFont(ofSize: 22, weight: .bold)
        @MainActor
        public static let uiHeadline = UIFont.systemFont(ofSize: 17, weight: .semibold)
        @MainActor
        public static let uiBody = UIFont.systemFont(ofSize: 15, weight: .regular)
        @MainActor
        public static let uiCallout = UIFont.systemFont(ofSize: 14, weight: .regular)
        @MainActor
        public static let uiFootnote = UIFont.systemFont(ofSize: 13, weight: .regular)
        @MainActor
        public static let uiCaption = UIFont.systemFont(ofSize: 12, weight: .regular)
        @MainActor
        public static let uiSection = UIFont.systemFont(ofSize: 11, weight: .medium)
    }
}
