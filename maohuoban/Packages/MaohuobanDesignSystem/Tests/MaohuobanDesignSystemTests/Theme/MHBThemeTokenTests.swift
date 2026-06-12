import Testing
import UIKit
import SwiftUI
@testable import MaohuobanDesignSystem

@Suite("毛伙伴主题 Token")
struct MHBThemeTokenTests {
    @Test("品牌色与 HTML 设计稿保持一致")
    func brandColorsMatchHTMLSpec() {
        #expect(MHBTheme.ColorToken.primary.hex == "#4F8CFF")
        #expect(MHBTheme.ColorToken.primaryLight.hex == "#6BCBFF")
        #expect(MHBTheme.ColorToken.primaryDark.hex == "#3A6FCC")
        #expect(MHBTheme.ColorToken.background.hex == "#F7F9FC")
    }

    @Test("文字层级与语义色保持稳定")
    func semanticColorsRemainStable() {
        #expect(MHBTheme.ColorToken.labelPrimary.hex == "#1A1D26")
        #expect(MHBTheme.ColorToken.labelSecondary.hex == "#6E7681")
        #expect(MHBTheme.ColorToken.labelTertiary.hex == "#9CA3AF")
        #expect(MHBTheme.ColorToken.success.hex == "#34C759")
        #expect(MHBTheme.ColorToken.warning.hex == "#FF9500")
        #expect(MHBTheme.ColorToken.danger.hex == "#FF3B30")
    }

    @Test("间距与圆角使用 HTML 设计稿基准")
    func spacingAndRadiusMatchHTMLSpec() {
        #expect(MHBTheme.Spacing.s1 == 4)
        #expect(MHBTheme.Spacing.s2 == 8)
        #expect(MHBTheme.Spacing.s3 == 12)
        #expect(MHBTheme.Spacing.s4 == 16)
        #expect(MHBTheme.Spacing.s5 == 20)
        #expect(MHBTheme.Spacing.s6 == 24)
        #expect(MHBTheme.Spacing.s8 == 32)

        #expect(MHBTheme.Radius.small == 8)
        #expect(MHBTheme.Radius.medium == 12)
        #expect(MHBTheme.Radius.large == 16)
        #expect(MHBTheme.Radius.extraLarge == 20)
        #expect(MHBTheme.Radius.extraExtraLarge == 24)
        #expect(MHBTheme.Radius.full == 9999)
    }

    @MainActor
    @Test("UIKit 桥接颜色可复用同一套 token")
    func uiKitBridgeUsesSameColorToken() {
        let color = MHBTheme.ColorToken.primary.uiColor
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        #expect(color.getRed(&red, green: &green, blue: &blue, alpha: &alpha))
        #expect(Int(round(red * 255)) == 79)
        #expect(Int(round(green * 255)) == 140)
        #expect(Int(round(blue * 255)) == 255)
        #expect(alpha == 1)
    }
}
