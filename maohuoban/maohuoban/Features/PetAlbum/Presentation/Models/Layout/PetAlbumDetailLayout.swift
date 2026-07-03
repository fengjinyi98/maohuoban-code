import Foundation

// PetAlbumDetailLayout 相册详情布局参数
// 核心职责：
// - 固化沉浸式主图和照片网格的几何规则
// - 为测试提供纯计算入口，避免布局规则散落在视图中
enum PetAlbumDetailLayout {
    nonisolated static let gridColumnCount = 3
    nonisolated static let gridSpacing: CGFloat = 2
    nonisolated static let heroRotationSeconds: UInt64 = 4
    nonisolated static let heroRotationMinimumAssetCount = 6
    nonisolated static let chromeIconSize: CGFloat = 44
    nonisolated static let heroDefaultScale: CGFloat = 1.08
    nonisolated static let heroShrinkSpeedMultiplier: CGFloat = 8

    nonisolated static func heroHeight(viewportHeight: CGFloat) -> CGFloat {
        max(viewportHeight * 0.55, 1)
    }

    nonisolated static func gridItemWidth(containerWidth: CGFloat) -> CGFloat {
        let spacingTotal = CGFloat(gridColumnCount - 1) * gridSpacing
        return max((containerWidth - spacingTotal) / CGFloat(gridColumnCount), 1)
    }

    nonisolated static func gridWidth(containerWidth: CGFloat) -> CGFloat {
        max(containerWidth, 1)
    }

    nonisolated static func shouldShowHero(
        assetCount: Int,
        uploadPlaceholderCount: Int
    ) -> Bool {
        assetCount > 0 || uploadPlaceholderCount > 0
    }

    nonisolated static func nextHeroIndex(current: Int, assetCount: Int) -> Int {
        guard assetCount > 0 else {
            return 0
        }
        return (current + 1) % assetCount
    }

    nonisolated static func shouldRotateHero(assetCount: Int) -> Bool {
        assetCount >= heroRotationMinimumAssetCount
    }

    nonisolated static func bottomChromePadding(bottomInset: CGFloat) -> CGFloat {
        max(bottomInset, 0)
    }

    nonisolated static func heroStretchMetrics(
        frameMinY: CGFloat,
        baseHeroHeight: CGFloat
    ) -> PetAlbumDetailHeroStretchMetrics {
        let stretch = max(frameMinY, 0)
        let upwardScroll = max(-frameMinY, 0)
        let shrinkRatio = max(heroDefaultScale - 1, 0)
        let upwardShrinkProgress = min(
            upwardScroll / max(baseHeroHeight, 1) * heroShrinkSpeedMultiplier,
            1
        )

        let scale: CGFloat
        if stretch > 0 {
            scale = heroDefaultScale + stretch / max(baseHeroHeight, 1)
        } else {
            scale = heroDefaultScale - upwardShrinkProgress * shrinkRatio
        }

        return PetAlbumDetailHeroStretchMetrics(scale: scale, verticalOffset: 0)
    }

    nonisolated static func visibleUploadPlaceholders(
        assetCount: Int,
        uploadPlaceholders: [PetAlbumUploadPlaceholder]
    ) -> [PetAlbumUploadPlaceholder] {
        uploadPlaceholders.filter { placeholder in
            placeholder.targetAssetIndex >= assetCount
        }
    }
}

// PetAlbumDetailHeroStretchMetrics 相册头图缩放指标
// 核心职责：
// - 描述下拉放大和上滑收敛的视觉变换
// - 保持头图滚动计算为纯函数
nonisolated struct PetAlbumDetailHeroStretchMetrics: Equatable {
    let scale: CGFloat
    let verticalOffset: CGFloat
}
