import Observation
import SwiftUI
import UIKit
import MaohuobanDesignSystem

// HomeDashboardThemeStore 首页主题状态模型
// 核心职责：
// - 根据当前宠物头图提取首页背景基色
// - 独立管理首页 Liquid Glass 所需的局部明暗模式
@MainActor
@Observable
final class HomeDashboardThemeStore {
    private(set) var baseThemeColor: Color = MHBTheme.ColorToken.background.color
    private(set) var colorScheme: ColorScheme = .light

    func backgroundColor(scrollProgress: CGFloat) -> Color {
        baseThemeColor.homeAdjustedForScroll(progress: scrollProgress)
    }

    func update(selectedPet: HomeDashboardSnapshot.PetHeroSummary?) {
        guard let selectedPet else {
            applyFallbackThemeColor()
            return
        }

        let assetName = selectedPet.heroImageAssetName ?? "HomePetHeroMock"
        guard let image = UIImage(named: assetName) else {
            applyFallbackThemeColor()
            return
        }

        let extracted = MHBImageAverageColorExtractor.extractHighestAverageColor(
            from: image,
            segmentsCount: 5
        )

        if let extracted {
            baseThemeColor = Color(uiColor: extracted)
            colorScheme = Self.localColorScheme(for: extracted, current: colorScheme)
        } else {
            applyFallbackThemeColor()
        }
    }

    private func applyFallbackThemeColor() {
        baseThemeColor = MHBTheme.ColorToken.background.color
        colorScheme = .light
    }

    private static func localColorScheme(for color: UIColor, current: ColorScheme) -> ColorScheme {
        let luminance = MHBColorMetrics.relativeLuminance(of: color)

        switch current {
        case .dark:
            return luminance > 0.46 ? .light : .dark
        case .light:
            return luminance < 0.38 ? .dark : .light
        @unknown default:
            return luminance < 0.42 ? .dark : .light
        }
    }
}

// Color 首页滚动背景调色能力
// 核心职责：
// - 将头图主色转换为适合 Liquid Glass 承载的背景色
// - 根据首页滚动进度收敛背景明度与饱和度
private extension Color {
    func homeAdjustedForScroll(progress: CGFloat) -> Color {
        let uiColor = UIColor(self)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        guard uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else {
            return self
        }

        let targetSaturation: CGFloat
        let targetBrightness: CGFloat

        if saturation < 0.10 {
            targetSaturation = 0
            targetBrightness = 0.22
        } else {
            targetSaturation = max(saturation, 0.48)
            targetBrightness = 0.28
        }

        let minBrightness: CGFloat = 0.06
        let minSaturation: CGFloat = saturation < 0.10 ? 0 : 0.12
        let clampedProgress = min(max(progress, 0), 1)
        let currentSaturation = targetSaturation - (targetSaturation - minSaturation) * clampedProgress
        let currentBrightness = targetBrightness - (targetBrightness - minBrightness) * clampedProgress

        return Color(
            hue: Double(hue),
            saturation: Double(currentSaturation),
            brightness: Double(currentBrightness),
            opacity: Double(alpha)
        )
    }
}
