import SwiftUI
import MaohuobanDesignSystem

// PetAlbumDetailContent 相册详情滚动内容
// 核心职责：
// - 组合沉浸式轮播主图和三列照片网格
// - 让沉浸式主图直接扩展到状态栏区域
struct PetAlbumDetailContent: View {
    let album: PetAlbumSummary
    let assets: [PetAlbumAsset]
    let heroHeight: CGFloat
    let containerWidth: CGFloat
    let containerHeight: CGFloat
    let bottomContentInset: CGFloat
    let uploadPlaceholders: [PetAlbumUploadPlaceholder]
    let selectedAssetIDs: Set<String>
    let isSelectionMode: Bool
    let onToggleSelection: (PetAlbumAsset) -> Void
    let onDeleteAsset: (PetAlbumAsset) -> Void
    let onUpload: () -> Void
    @State private var viewportHeight: CGFloat = 0
    @State private var uploadPlaceholderFrames: [String: CGRect] = [:]
    @State private var lastScrollTargetID: String?

    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    if shouldShowHero {
                        PetAlbumDetailHero(
                            album: album,
                            assets: assets,
                            heroHeight: heroHeight
                        )
                    }

                    if shouldShowEmptyState {
                        PetAlbumDetailEmptyState(
                            containerHeight: containerHeight,
                            onUpload: onUpload
                        )
                            .frame(width: containerWidth)
                    } else {
                        PetAlbumMosaicGrid(
                            assets: assets,
                            uploadPlaceholders: uploadPlaceholders,
                            selectedAssetIDs: selectedAssetIDs,
                            isSelectionMode: isSelectionMode,
                            onToggleSelection: onToggleSelection,
                            onDeleteAsset: onDeleteAsset
                        )
                        .frame(width: PetAlbumDetailLayout.gridWidth(containerWidth: containerWidth))
                    }
                }
                .frame(width: containerWidth)
                .padding(.bottom, bottomContentInset)
            }
            .coordinateSpace(name: "petAlbumDetailScrollView")
            .ignoresSafeArea(edges: .top)
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.containerSize.height
            } action: { _, metrics in
                viewportHeight = metrics
            }
            .onPreferenceChange(PetAlbumUploadPlaceholderFramePreferenceKey.self) { frames in
                uploadPlaceholderFrames = frames
                scrollToUploadPlaceholderIfNeeded(scrollProxy: scrollProxy)
            }
            .onChange(of: uploadScrollTargetID) { _, targetID in
                guard targetID != nil else {
                    return
                }
                lastScrollTargetID = nil
                scrollToUploadPlaceholderIfNeeded(scrollProxy: scrollProxy)
            }
        }
    }

    private var shouldShowHero: Bool {
        PetAlbumDetailLayout.shouldShowHero(
            assetCount: assets.count,
            uploadPlaceholderCount: uploadPlaceholders.count
        )
    }

    private var shouldShowEmptyState: Bool {
        assets.isEmpty && uploadPlaceholders.isEmpty
    }

    private var uploadScrollTargetID: String? {
        PetAlbumDetailLayout.visibleUploadPlaceholders(
            assetCount: assets.count,
            uploadPlaceholders: uploadPlaceholders
        ).first?.scrollAnchorID
    }

    private func scrollToUploadPlaceholderIfNeeded(scrollProxy: ScrollViewProxy) {
        guard let targetID = uploadScrollTargetID,
              lastScrollTargetID != targetID,
              let frame = uploadPlaceholderFrames[targetID],
              viewportHeight > 0 else {
            return
        }

        let visibleMinY: CGFloat = 0
        let visibleMaxY = viewportHeight
        let isVisible = frame.minY >= visibleMinY && frame.maxY <= visibleMaxY
        guard isVisible == false else {
            lastScrollTargetID = targetID
            return
        }

        lastScrollTargetID = targetID
        withAnimation(.easeInOut(duration: 0.28)) {
            scrollProxy.scrollTo(targetID, anchor: .center)
        }
    }
}

// PetAlbumUploadPlaceholderFramePreferenceKey 上传占位位置偏好
// 核心职责：
// - 收集上传占位在滚动坐标系里的 frame
// - 为自动滚动可见性判断提供布局证据
struct PetAlbumUploadPlaceholderFramePreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]

    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, newValue in newValue })
    }
}

// PetAlbumDetailEmptyState 相册详情空态
// 核心职责：
// - 在相册暂无照片时替代沉浸式头图和照片网格
// - 通过同一个上传入口进入媒体选择流程
private struct PetAlbumDetailEmptyState: View {
    let containerHeight: CGFloat
    let onUpload: () -> Void

    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s4) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)

            VStack(spacing: MHBTheme.Spacing.s2) {
                Text("还没有照片")
                    .font(MHBTheme.Typography.title.weight(.semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

                Text("上传第一张照片，开始整理这个相册。")
                    .font(MHBTheme.Typography.callout)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    .multilineTextAlignment(.center)
            }

            Button(action: onUpload) {
                Label("上传照片", systemImage: "photo.badge.plus")
                    .font(MHBTheme.Typography.callout.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, MHBTheme.Spacing.s5)
                    .padding(.vertical, MHBTheme.Spacing.s3)
                    .background(MHBTheme.ColorToken.primary.color, in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("petAlbum.detail.empty.uploadButton")
        }
        .padding(.horizontal, MHBTheme.Spacing.s6)
        .frame(maxWidth: .infinity)
        .frame(minHeight: containerHeight)
        .accessibilityIdentifier("petAlbum.detail.emptyState")
    }
}
