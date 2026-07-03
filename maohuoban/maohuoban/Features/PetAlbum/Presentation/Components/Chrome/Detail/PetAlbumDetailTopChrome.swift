import SwiftUI
import MaohuobanDesignSystem

// PetAlbumDetailTopChrome 相册详情顶部操作区
// 核心职责：
// - 在沉浸式相册顶部承载返回、选择和分享入口
// - 切换选择态时展示全选和关闭操作
struct PetAlbumDetailTopChrome: View {
    let isSelectionMode: Bool
    let onBack: () -> Void
    let onToggleSelectionMode: () -> Void
    let onSelectAll: () -> Void
    let onShare: () -> Void

    var body: some View {
        GlassEffectContainer(spacing: MHBTheme.Spacing.s3) {
            HStack(spacing: MHBTheme.Spacing.s3) {
                if isSelectionMode {
                    PetAlbumChromeCapsuleButton(title: "全选", action: onSelectAll)

                    Spacer()

                    PetAlbumChromeIconButton(
                        systemImage: "xmark",
                        accessibilityLabel: "退出选择",
                        action: onToggleSelectionMode
                    )
                } else {
                    PetAlbumChromeIconButton(
                        systemImage: "chevron.left",
                        accessibilityLabel: "返回",
                        action: onBack
                    )

                    Spacer()

                    PetAlbumChromeCapsuleButton(title: "选择", action: onToggleSelectionMode)

                    PetAlbumChromeIconButton(
                        systemImage: "square.and.arrow.up",
                        accessibilityLabel: "分享",
                        action: onShare
                    )
                }
            }
        }
        .accessibilityIdentifier("petAlbum.detail.topChrome")
    }
}
