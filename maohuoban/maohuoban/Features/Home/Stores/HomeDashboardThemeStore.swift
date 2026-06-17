import Observation
import SwiftUI
import UIKit
import MaohuobanDesignSystem

// HomeDashboardThemeSnapshot 首页主题快照
// 核心职责：
// - 承载首页主题 Store 的首帧可复用状态
// - 支持预览页在呈现前完成主题预热
struct HomeDashboardThemeSnapshot {
    let baseThemeColor: Color
    let colorScheme: ColorScheme
    let heroContentColorScheme: ColorScheme

    func backgroundColor(scrollProgress: CGFloat) -> Color {
        baseThemeColor.homeAdjustedForScroll(progress: scrollProgress)
    }
}

// HomeDashboardThemeStore 首页主题状态模型
// 核心职责：
// - 优先消费后端计算出的首页背景主题色
// - 固定首页 Liquid Glass 使用暗色局部模式
// - 为头图内容提供独立的明暗派生状态
// 设计约束：
// - 真实远端媒体不在前端下载图片计算颜色
// - 本地取色只作为 Mock 和本地预览资源兜底
@MainActor
@Observable
final class HomeDashboardThemeStore {
    private(set) var baseThemeColor: Color = MHBTheme.ColorToken.background.color
    private(set) var colorScheme: ColorScheme = .dark
    private(set) var heroContentColorScheme: ColorScheme = .dark

    init(snapshot: HomeDashboardThemeSnapshot? = nil) {
        guard let snapshot else { return }

        baseThemeColor = snapshot.baseThemeColor
        colorScheme = snapshot.colorScheme
        heroContentColorScheme = snapshot.heroContentColorScheme
    }

    var snapshot: HomeDashboardThemeSnapshot {
        HomeDashboardThemeSnapshot(
            baseThemeColor: baseThemeColor,
            colorScheme: colorScheme,
            heroContentColorScheme: heroContentColorScheme
        )
    }

    func backgroundColor(scrollProgress: CGFloat) -> Color {
        baseThemeColor.homeAdjustedForScroll(progress: scrollProgress)
    }

    func update(
        selectedPet: HomeDashboardSnapshot.PetHeroSummary?,
        heroImageSize: CGSize = .zero
    ) async {
        guard let selectedPet else {
            applyFallbackThemeColor()
            return
        }

        if applyBackendThemeColor(from: selectedPet) {
            return
        }

        guard let image = await Self.heroImage(for: selectedPet.heroMedia) else {
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

    private func applyBackendThemeColor(from selectedPet: HomeDashboardSnapshot.PetHeroSummary) -> Bool {
        guard let color = selectedPet.heroThemeColorHex.flatMap(UIColor.init(mhbHexString:)) else {
            return false
        }

        baseThemeColor = Color(uiColor: color)
        heroContentColorScheme = selectedPet.heroContentColorScheme?.swiftUIColorScheme ?? .dark
        colorScheme = .dark
        return true
    }

    private func applyFallbackThemeColor() {
        baseThemeColor = MHBTheme.ColorToken.background.color
        colorScheme = .dark
        heroContentColorScheme = .dark
    }

    private static func heroImage(
        for media: HomeDashboardSnapshot.PetHeroSummary.HeroMedia
    ) async -> UIImage? {
        switch media {
        case .image(let assetName):
            return UIImage(named: assetName)
        case .remoteImage(_, let fallbackAssetName):
            return UIImage(named: fallbackAssetName)
        case .video(let resourceName, let fileExtension, let fallbackImageAssetName):
            return await MHBVideoFirstFrameExtractor.extract(
                resourceName: resourceName,
                fileExtension: fileExtension
            ) ?? fallbackImageAssetName.flatMap { UIImage(named: $0) }
        case .remoteVideo(_, _, let fallbackImageAssetName):
            return fallbackImageAssetName.flatMap { UIImage(named: $0) }
        }
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

private extension HomeDashboardSnapshot.HeroContentColorScheme {
    var swiftUIColorScheme: ColorScheme {
        switch self {
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

private extension UIColor {
    convenience init?(mhbHexString: String) {
        let hex = mhbHexString.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard hex.count == 6, let value = UInt32(hex, radix: 16) else {
            return nil
        }

        let red = CGFloat((value >> 16) & 0xFF) / 255.0
        let green = CGFloat((value >> 8) & 0xFF) / 255.0
        let blue = CGFloat(value & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue, alpha: 1)
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
