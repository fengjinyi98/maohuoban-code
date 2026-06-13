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

    @Test("暗色 token 与设计稿暗色映射一致")
    func darkTokensMatchSpec() {
        // 背景与卡片
        #expect(MHBTheme.ColorToken.background.darkHex == "#000000")
        #expect(MHBTheme.ColorToken.cardSolid.darkHex == "#1C1C1E")
        #expect(MHBTheme.ColorToken.card.darkHex == "rgba(20,20,22,0.75)")

        // 文字层级翻转
        #expect(MHBTheme.ColorToken.labelPrimary.darkHex == "#FFFFFF")
        #expect(MHBTheme.ColorToken.labelSecondary.darkHex == "#98989D")
        #expect(MHBTheme.ColorToken.labelTertiary.darkHex == "#6E6E73")
        #expect(MHBTheme.ColorToken.labelQuaternary.darkHex == "#3A3A3C")

        // 分割线翻转
        #expect(MHBTheme.ColorToken.separator.darkHex == "rgba(255,255,255,0.08)")
        #expect(MHBTheme.ColorToken.separatorSoft.darkHex == "rgba(255,255,255,0.04)")

        // Toast
        #expect(MHBTheme.ColorToken.toastBackground.darkHex == "#2C2C2E")
        #expect(MHBTheme.ColorToken.toastBorder.darkHex == "rgba(255,255,255,0.12)")
    }

    @Test("语义色亮暗一致，dark 回退到 light")
    func semanticColorsUseLightForDark() {
        #expect(MHBTheme.ColorToken.success.darkHex == MHBTheme.ColorToken.success.hex)
        #expect(MHBTheme.ColorToken.warning.darkHex == MHBTheme.ColorToken.warning.hex)
        #expect(MHBTheme.ColorToken.danger.darkHex == MHBTheme.ColorToken.danger.hex)
        #expect(MHBTheme.ColorToken.teal.darkHex == MHBTheme.ColorToken.teal.hex)
        #expect(MHBTheme.ColorToken.purple.darkHex == MHBTheme.ColorToken.purple.hex)
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

    @Test("图标尺寸 token 使用页面占位根视图基准")
    func iconSizesMatchPlaceholderSpec() {
        #expect(MHBTheme.IconSize.small == 16)
        #expect(MHBTheme.IconSize.medium == 20)
        #expect(MHBTheme.IconSize.large == 28)
        #expect(MHBTheme.IconSize.avatar == 56)
        #expect(MHBTheme.IconSize.tabRootPlaceholder == 48)
    }

    @MainActor
    @Test("亮色模式下 UIColor 桥接颜色与 light 分量一致")
    func uiKitBridgeMatchesLightComponents() {
        let lightTraits = UITraitCollection(userInterfaceStyle: .light)
        let color = MHBTheme.ColorToken.primary.uiColor.resolvedColor(with: lightTraits)

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

    @MainActor
    @Test("暗色模式下 UIColor 桥接颜色与 dark 分量一致")
    func uiKitBridgeMatchesDarkComponents() {
        let darkTraits = UITraitCollection(userInterfaceStyle: .dark)
        let color = MHBTheme.ColorToken.labelPrimary.uiColor.resolvedColor(with: darkTraits)

        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        #expect(color.getRed(&red, green: &green, blue: &blue, alpha: &alpha))
        #expect(Int(round(red * 255)) == 255)
        #expect(Int(round(green * 255)) == 255)
        #expect(Int(round(blue * 255)) == 255)
        #expect(alpha == 1)
    }
}
