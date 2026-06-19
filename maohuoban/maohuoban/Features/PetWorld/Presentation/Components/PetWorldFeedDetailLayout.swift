import SwiftUI
import MaohuobanDesignSystem

// PetWorldFeedDetailLayout 宠物世界详情布局参数
// 核心职责：
// - 统一详情页主图、评论和底部操作栏尺寸
// - 收敛详情页局部动画参数
enum PetWorldFeedDetailLayout {
    static let heroAspectRatio: CGFloat = 4 / 5
    static let heroCornerRadius: CGFloat = 40
    static let heroInnerBorderWidth: CGFloat = 4
    static let heroInnerBorderOpacity: CGFloat = 0.15
    static let heroHairlineOpacity: CGFloat = 0.08
    static let authorAvatarSize: CGFloat = 48
    static let commentAvatarSize: CGFloat = 36
    static let inputAvatarSize: CGFloat = 32
    static let commentComposerAvatarSize: CGFloat = 36
    static let commentComposerTextMinHeight: CGFloat = 44
    static let commentComposerTextMaxLines: CGFloat = 5
    static let commentComposerTextHorizontalPadding: CGFloat = MHBTheme.Spacing.s4
    static let commentComposerTextVerticalPadding: CGFloat = MHBTheme.Spacing.s3
    static let inputHeight: CGFloat = 40
    static let inputVerticalPadding: CGFloat = MHBTheme.Spacing.s3
    static let bottomActionHitSize: CGFloat = 40
    static let likeFeedbackScale: CGFloat = 1.22
    static let previewPresentationAnimation = Animation.timingCurve(0.22, 0.88, 0.24, 1, duration: 0.32)
    static let previewDismissAnimation = Animation.timingCurve(0.26, 0.82, 0.24, 1, duration: 0.30)
    static let commentComposerAnimation = Animation.easeInOut(duration: 0.24)
    static let likePressAnimation = Animation.smooth(duration: 0.18, extraBounce: 0.35)
    static let likeReleaseAnimation = Animation.interactiveSpring(
        response: 0.28,
        dampingFraction: 0.62,
        blendDuration: 0.08
    )

    static var heroShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            cornerRadii: RectangleCornerRadii(
                topLeading: 0,
                bottomLeading: heroCornerRadius,
                bottomTrailing: heroCornerRadius,
                topTrailing: 0
            ),
            style: .continuous
        )
    }

    static var commentComposerShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            cornerRadii: RectangleCornerRadii(
                topLeading: MHBTheme.Radius.extraExtraLarge,
                bottomLeading: 0,
                bottomTrailing: 0,
                topTrailing: MHBTheme.Radius.extraExtraLarge
            ),
            style: .continuous
        )
    }

    static func inputBarReservedHeight(bottomSafeArea: CGFloat) -> CGFloat {
        inputHeight + inputVerticalPadding + bottomSafeArea
    }

}
