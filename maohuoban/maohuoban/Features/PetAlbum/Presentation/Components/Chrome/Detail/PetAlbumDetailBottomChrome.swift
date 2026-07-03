import SwiftUI
import MaohuobanDesignSystem

// PetAlbumDetailBottomChrome 相册详情底部操作区
// 核心职责：
// - 普通态展示右下角上传入口
// - 选择态展示分享、选择计数和删除入口
struct PetAlbumDetailBottomChrome: View {
    let isSelectionMode: Bool
    let selectedCount: Int
    let bottomInset: CGFloat
    let onUpload: () -> Void
    let onShare: () -> Void
    let onDeleteSelection: () -> Void

    var body: some View {
        if isSelectionMode {
            selectionBar
        } else {
            uploadButton
        }
    }

    private var uploadButton: some View {
        HStack {
            Spacer()

            PetAlbumChromeIconButton(
                systemImage: "plus",
                accessibilityLabel: "上传照片",
                action: onUpload
            )
        }
        .padding(.horizontal, MHBTheme.Spacing.s4)
        .padding(.bottom, PetAlbumDetailLayout.bottomChromePadding(bottomInset: bottomInset))
        .accessibilityIdentifier("petAlbum.detail.uploadButton")
    }

    private var selectionBar: some View {
        GlassEffectContainer(spacing: MHBTheme.Spacing.s4) {
            HStack {
                PetAlbumChromeIconButton(
                    systemImage: "square.and.arrow.up",
                    accessibilityLabel: "分享已选照片",
                    action: onShare
                )

                Spacer()

                PetAlbumChromeCapsuleButton(
                    title: selectedCount > 0 ? "\(selectedCount) 个项目" : "选择项目",
                    action: {}
                )
                .allowsHitTesting(false)

                Spacer()

                PetAlbumChromeIconButton(
                    systemImage: "trash",
                    accessibilityLabel: "删除已选照片",
                    action: onDeleteSelection
                )
            }
        }
        .padding(.horizontal, MHBTheme.Spacing.s4)
        .padding(.bottom, PetAlbumDetailLayout.bottomChromePadding(bottomInset: bottomInset))
        .accessibilityIdentifier("petAlbum.detail.selectionBar")
    }
}
