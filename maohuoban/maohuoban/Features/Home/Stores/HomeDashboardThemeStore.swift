import Observation
import SwiftUI
import UIKit
import MaohuobanDesignSystem

// HomeDashboardThemeStore 首页主题状态模型
// 核心职责：
// - 根据当前宠物头图提取首页背景基色
// - 固定首页 Liquid Glass 使用暗色局部模式
// - 为头图内容提供独立的明暗派生状态
@MainActor
@Observable
final class HomeDashboardThemeStore {
    private(set) var baseThemeColor: Color = MHBTheme.ColorToken.background.color
    private(set) var colorScheme: ColorScheme = .dark
    private(set) var heroContentColorScheme: ColorScheme = .dark

    func backgroundColor(scrollProgress: CGFloat) -> Color {
        baseThemeColor.homeAdjustedForScroll(progress: scrollProgress)
    }

    func update(
        selectedPet: HomeDashboardSnapshot.PetHeroSummary?,
        heroImageSize: CGSize = .zero
    ) {
        guard let selectedPet else {
            applyFallbackThemeColor()
            return
        }

        let assetName = selectedPet.heroImageAssetName ?? "HomePetHeroMock"

        guard let image = UIImage(named: assetName) else {
            applyFallbackThemeColor()
            return
        }

        let visibleAverageColor = MHBImageAverageColorExtractor.extractScaledToFillVisibleAverageColor(
            from: image,
            targetSize: heroImageSize
        )
        let visibleHighestAverageColor = MHBImageAverageColorExtractor.extractScaledToFillVisibleHighestAverageColor(
            from: image,
            targetSize: heroImageSize,
            segmentsCount: 5
        )
        let extracted = visibleAverageColor ?? visibleHighestAverageColor ?? MHBImageAverageColorExtractor.extractHighestAverageColor(
            from: image,
            segmentsCount: 5
        )

        if let extracted {
            let nextHeroContentColorScheme = Self.localColorScheme(for: extracted, current: heroContentColorScheme)
            baseThemeColor = Color(uiColor: extracted)
            heroContentColorScheme = nextHeroContentColorScheme
        } else {
            applyFallbackThemeColor()
        }
    }

    private func applyFallbackThemeColor() {
        baseThemeColor = MHBTheme.ColorToken.background.color
        colorScheme = .dark
        heroContentColorScheme = .dark
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
// - 保留头图主色的色相与饱和度
// - 根据首页滚动进度只压低背景明度
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

        let clampedProgress = min(max(progress, 0), 1)
        let initialBrightness = brightness * 0.60
        let minimumBrightness = brightness * 0.30
        let currentBrightness = initialBrightness - (initialBrightness - minimumBrightness) * clampedProgress

        return Color(
            hue: Double(hue),
            saturation: Double(saturation),
            brightness: Double(currentBrightness),
            opacity: Double(alpha)
        )
    }
}
