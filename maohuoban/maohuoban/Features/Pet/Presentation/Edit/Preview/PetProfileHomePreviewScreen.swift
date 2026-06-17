import SwiftUI
import MaohuobanDesignSystem
import UIKit

struct PetProfileHomePreviewScreen: View {
    let context: PetProfileHomePreviewContext
    let initialThemeSnapshot: HomeDashboardThemeSnapshot
    let topSafeAreaInset: CGFloat
    let onDismiss: () -> Void

    @State private var themeStore: HomeDashboardThemeStore
    @State private var scrollOffset: CGFloat = 0
    @State private var isThemeReady = true

    init(
        context: PetProfileHomePreviewContext,
        initialThemeSnapshot: HomeDashboardThemeSnapshot,
        topSafeAreaInset: CGFloat,
        onDismiss: @escaping () -> Void
    ) {
        self.context = context
        self.initialThemeSnapshot = initialThemeSnapshot
        self.topSafeAreaInset = topSafeAreaInset
        self.onDismiss = onDismiss
        _themeStore = State(initialValue: HomeDashboardThemeStore(snapshot: initialThemeSnapshot))
        _isThemeReady = State(initialValue: true)
    }

    private var backgroundColor: Color {
        guard isThemeReady else {
            return initialThemeSnapshot.backgroundColor(scrollProgress: 0)
        }

        return themeStore.backgroundColor(
            scrollProgress: Self.backgroundDimmingProgress(for: scrollOffset)
        )
    }

    var body: some View {
        GeometryReader { geometry in
            let heroImageWidth = max(geometry.size.width, 1)

            ZStack(alignment: .topTrailing) {
                backgroundColor
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: MHBTheme.Spacing.s4) {
                        HomeImmersivePetHeaderSection(
                            pet: context.pet,
                            displayName: context.displayName,
                            width: heroImageWidth,
                            fusionColor: backgroundColor,
                            contentColorScheme: themeStore.heroContentColorScheme,
                            scrollOffset: scrollOffset,
                            editProfileRoute: nil,
                            showsEditProfileButton: false
                        )

                        Color.clear
                            .frame(height: max(geometry.size.height - HomeImmersivePetHeaderLayout.imageHeight, 0))
                    }
                    .frame(maxWidth: .infinity)
                }
                .coordinateSpace(name: "petProfileHomePreviewScrollView")
                .ignoresSafeArea(edges: .top)
                .onScrollGeometryChange(for: CGFloat.self) { geometry in
                    geometry.contentOffset.y
                } action: { _, offset in
                    scrollOffset = max(offset, 0)
                }

                Button(action: onDismiss) {
                    HomeImmersiveHeaderCapsuleLabel(title: "退出预览")
                }
                .buttonStyle(.plain)
                .padding(.top, topSafeAreaInset + MHBTheme.Spacing.s1)
                .padding(.trailing, MHBTheme.Spacing.s4)
                .accessibilityLabel("关闭预览")
            }
            .task(id: themeUpdateID(width: heroImageWidth)) {
                await themeStore.update(
                    selectedPet: context.pet,
                    heroImageSize: CGSize(
                        width: heroImageWidth,
                        height: HomeImmersivePetHeaderLayout.backgroundDimmingReferenceHeight
                    )
                )
                isThemeReady = true
            }
        }
        .environment(\.colorScheme, .dark)
        .accessibilityIdentifier("pet.profileHomePreview.screen")
    }

    private func themeUpdateID(width: CGFloat) -> String {
        Self.themeUpdateID(context: context, width: width)
    }

    private static func themeUpdateID(context: PetProfileHomePreviewContext, width: CGFloat) -> String {
        switch context.pet.heroMedia {
        case .image(let assetName):
            "image-\(assetName)-\(Int(width.rounded()))"
        case .remoteImage(let urlString, _):
            "remote-image-\(urlString)-\(Int(width.rounded()))"
        case .video(let resourceName, let fileExtension, _):
            "video-\(resourceName).\(fileExtension)-\(Int(width.rounded()))"
        case .remoteVideo(let urlString, let fallbackImageURLString, _):
            "remote-video-\(urlString)-\(fallbackImageURLString ?? "none")-\(Int(width.rounded()))"
        }
    }

    private static var backgroundDimmingStartOffset: CGFloat {
        HomeImmersivePetHeaderLayout.backgroundDimmingReferenceHeight * 0.50
    }

    private static var backgroundDimmingEndOffset: CGFloat {
        HomeImmersivePetHeaderLayout.backgroundDimmingReferenceHeight
    }

    private static func backgroundDimmingProgress(for offset: CGFloat) -> CGFloat {
        let dimmingRange = max(backgroundDimmingEndOffset - backgroundDimmingStartOffset, 1)
        let rawProgress = (offset - backgroundDimmingStartOffset) / dimmingRange
        return min(max(rawProgress, 0), 1)
    }

}

// HomePreviewSafeAreaMetrics 首页预览安全区指标
// 核心职责：
// - 读取当前窗口顶部安全区，供 UIKit 自定义全屏预览的导航位控件定位
// - 将 UIKit 安全区访问隔离在预览呈现基础能力附近
