import SwiftUI
import UIKit
import MaohuobanDesignSystem

// HomeDashboardLoadedView 首页已加载内容
// 核心职责：
// - 按首页快照组合各业务 section
// - 保持 HomeRootScreen 只负责状态切换
struct HomeDashboardLoadedView: View {
    let snapshot: HomeDashboardSnapshot
    let locationTitle: String
    let onRefreshLocation: () -> Void
    let onSelectPet: (String) -> Void

    @State private var heroColorPalette = HomeImmersiveHeroColorPalette.fallback

    private static let heroColorDebugTag = "HomeHeroColor"

    var body: some View {
        let routingContext = HomeActionRoutingContext(snapshot: snapshot)
        let heroAssetName = snapshot.selectedPet.map { $0.heroImageAssetName ?? "HomePetHeroMock" }

        GeometryReader { geometry in
            let heroImageWidth = max(geometry.size.width, 1)
            let heroColorRequest = HomeImmersiveHeroColorRequest(
                assetName: heroAssetName,
                width: Int(heroImageWidth.rounded())
            )

            ZStack(alignment: .topLeading) {
                HomeImmersiveHeroExtractedBackground(
                    palette: heroColorPalette,
                    isEnabled: snapshot.selectedPet != nil
                )
                .ignoresSafeArea()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: MHBTheme.Spacing.s4) {
                        if let selectedPet = snapshot.selectedPet {
                            HomeImmersivePetHeaderSection(
                                pet: selectedPet,
                                width: heroImageWidth
                            )
                        }

                        HomeDashboardContentSections(
                            snapshot: snapshot,
                            routingContext: routingContext,
                            onSelectPet: onSelectPet,
                            showsTopSpacing: snapshot.selectedPet == nil
                        )
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("home.dashboard")
                }
                .ignoresSafeArea(edges: snapshot.selectedPet == nil ? [] : .top)

                if snapshot.selectedPet != nil {
                    HomeImmersiveLocationButton(
                        title: locationTitle,
                        action: onRefreshLocation
                    )
                    .padding(.top, MHBTheme.Spacing.s1)
                    .padding(.horizontal, MHBTheme.Spacing.s4)
                }
            }
            .task(id: heroColorRequest) {
                updateHeroColorPalette(
                    for: heroColorRequest.assetName,
                    imageWidth: CGFloat(heroColorRequest.width)
                )
            }
        }
    }

    @MainActor
    private func updateHeroColorPalette(for assetName: String?, imageWidth: CGFloat) {
        Self.debugLog("palette task started assetName=\(assetName ?? "nil"), imageWidth=\(Self.debugNumber(imageWidth))")

        guard let assetName else {
            heroColorPalette = .fallback
            Self.debugLog("palette fallback applied because selectedPet is nil")
            return
        }

        guard let image = UIImage(named: assetName) else {
            heroColorPalette = .fallback
            Self.debugLog("palette fallback applied because UIImage load failed assetName=\(assetName)")
            return
        }

        Self.debugLog("image loaded assetName=\(assetName), size=\(Self.debugSize(image.size)), scale=\(Self.debugNumber(image.scale))")
        Self.debugLog(
            "fusion geometry pageOverlay=disabled, imageBottomY=\(Self.debugNumber(HomeImmersivePetHeaderLayout.imageHeight))"
        )

        let colors = MHBImageAverageColorExtractor.extractVerticalColors(
            from: image,
            count: 4,
            debugTag: Self.heroColorDebugTag
        )

        Self.debugLog("extract finished colorsCount=\(colors.count)")

        for (index, color) in colors.enumerated() {
            Self.debugLog("extract color index=\(index), rgba=\(Self.debugRGBA(color))")
        }

        let targetSize = CGSize(
            width: imageWidth,
            height: HomeImmersivePetHeaderLayout.imageHeight
        )
        let visibleBottomColor = MHBImageAverageColorExtractor.extractScaledToFillVisibleBottomColor(
            from: image,
            targetSize: targetSize,
            sampleHeightRatio: 0.30,
            debugTag: Self.heroColorDebugTag
        )
        let selectedColor = visibleBottomColor ?? colors.last

        guard let selectedColor else {
            heroColorPalette = .fallback
            Self.debugLog("palette fallback applied because visible and vertical extracted colors are empty")
            return
        }

        let opaqueColor = selectedColor.withAlphaComponent(1)
        heroColorPalette = HomeImmersiveHeroColorPalette(
            backgroundColor: Color(uiColor: opaqueColor),
            fogColor: Color(uiColor: opaqueColor),
            sourceAssetName: assetName,
            isResolved: true
        )
        Self.debugLog(
            "palette updated sourceAssetName=\(assetName), selected=\(visibleBottomColor == nil ? "verticalBottomFallback" : "scaledToFillVisibleBottom30"), rgba=\(Self.debugRGBA(opaqueColor))"
        )
    }

    private static func debugLog(_ message: @autoclosure () -> String) {
        print("[DEBUG:\(heroColorDebugTag)] \(message())")
    }

    private static func debugSize(_ size: CGSize) -> String {
        "w=\(debugNumber(size.width)), h=\(debugNumber(size.height))"
    }

    private static func debugNumber(_ value: CGFloat) -> String {
        String(format: "%.2f", Double(value))
    }

    private static func debugRGBA(_ color: UIColor) -> String {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        guard color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return "unresolved"
        }

        return "r=\(debugNumber(red)), g=\(debugNumber(green)), b=\(debugNumber(blue)), a=\(debugNumber(alpha))"
    }
}

// HomeImmersiveHeroColorRequest 首页头图取色请求
// 核心职责：
// - 将头图资源和当前显示宽度绑定为取色任务标识
// - 避免宽度稳定时重复执行取色实验
private struct HomeImmersiveHeroColorRequest: Equatable {
    let assetName: String?
    let width: Int
}

// HomeImmersiveHeroColorPalette 首页沉浸式头图实验色板
// 核心职责：
// - 保存当前头图提取出的背景承接色
// - 为背景层和头图雾化层提供同源颜色
private struct HomeImmersiveHeroColorPalette {
    let backgroundColor: Color
    let fogColor: Color
    let sourceAssetName: String?
    let isResolved: Bool

    static var fallback: HomeImmersiveHeroColorPalette {
        HomeImmersiveHeroColorPalette(
            backgroundColor: MHBTheme.ColorToken.background.color,
            fogColor: MHBTheme.ColorToken.background.color,
            sourceAssetName: nil,
            isResolved: false
        )
    }
}

// HomeImmersiveHeroExtractedBackground 首页头图提取色背景
// 核心职责：
// - 使用当前头图提取色承接头图外背景
// - 为 Apple Music 式头图融合实验提供稳定纯色底层
private struct HomeImmersiveHeroExtractedBackground: View {
    let palette: HomeImmersiveHeroColorPalette
    let isEnabled: Bool

    var body: some View {
        ZStack {
            MHBTheme.ColorToken.background.color

            if isEnabled {
                palette.backgroundColor
            }
        }
    }
}

// HomeDashboardContentSections 首页普通内容区
// 核心职责：
// - 组合沉浸式头图以外的首页业务模块
// - 统一维护普通 section 的页面边距
private struct HomeDashboardContentSections: View {
    let snapshot: HomeDashboardSnapshot
    let routingContext: HomeActionRoutingContext
    let onSelectPet: (String) -> Void
    let showsTopSpacing: Bool

    var body: some View {
        LazyVStack(alignment: .leading, spacing: MHBTheme.Spacing.s4) {
            HomeIdentityHeader(identity: snapshot.identity)

            if !snapshot.petSwitcher.isEmpty {
                HomePetSwitcherSection(
                    items: snapshot.petSwitcher,
                    onSelectPet: onSelectPet
                )
            }

            if let emptyState = snapshot.emptyState {
                HomeEmptyStateSection(
                    emptyState: emptyState,
                    recommendedContent: snapshot.recommendedContent,
                    routingContext: routingContext
                )
            }

            if let careSummary = snapshot.careSummary {
                HomeCareSummarySection(
                    summary: careSummary,
                    reminders: snapshot.reminders,
                    routingContext: routingContext
                )
            }

            if !snapshot.quickActions.isEmpty {
                HomeQuickActionsSection(
                    actions: snapshot.quickActions,
                    routingContext: routingContext
                )
            }

            if let partner = snapshot.partnerRecommendation {
                HomePartnerSection(partner: partner)
            }

            if !snapshot.recentTimeline.isEmpty {
                HomeTimelineSection(events: snapshot.recentTimeline)
            }

            if let merchantDashboard = snapshot.merchantDashboard {
                HomeMerchantDashboardSection(summary: merchantDashboard)
            }
        }
        .padding(.horizontal, MHBTheme.Spacing.s4)
        .padding(.top, showsTopSpacing ? MHBTheme.Spacing.s4 : 0)
        .padding(.bottom, MHBTheme.Spacing.s4)
    }
}

// HomeIdentityHeader 首页身份头部
// 核心职责：
// - 展示当前身份名称和认证状态
// - 为普通用户和商家首页建立上下文
private struct HomeIdentityHeader: View {
    let identity: HomeDashboardSnapshot.Identity

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s3) {
            Text(identity.displayName)
                .font(MHBTheme.Typography.largeTitle)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

            Spacer()

            if let badge = identity.verificationBadge {
                Text(badge)
                    .font(MHBTheme.Typography.caption)
                    .foregroundStyle(MHBTheme.ColorToken.primary.color)
                    .padding(.horizontal, MHBTheme.Spacing.s3)
                    .padding(.vertical, MHBTheme.Spacing.s2)
                    .background(MHBTheme.ColorToken.primaryBackground.color)
                    .clipShape(Capsule())
            }
        }
        .accessibilityIdentifier("home.identityHeader")
    }
}
