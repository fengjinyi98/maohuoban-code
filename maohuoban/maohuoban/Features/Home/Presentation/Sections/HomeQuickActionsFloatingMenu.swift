import Foundation
import SwiftUI
import MaohuobanDesignSystem

// HomeQuickActionsFloatingMenu 首页快捷动作浮动菜单
// 核心职责：
// - 在首页右下角承载加号按钮到动作面板的一体化膨胀动画
// - 复用首页路由语义并为动作项提供分层展示
struct HomeQuickActionsFloatingMenu: View {
    let actions: [HomeDashboardSnapshot.Action]
    let routingContext: HomeActionRoutingContext
    @Binding var isPresented: Bool
    let onAddReminder: () -> Void

    @State private var isExpandedContentVisible = false
    @State private var windowSafeAreaInsets = UIEdgeInsets.zero
    @State private var surfaceProgress: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            let effectiveBottomInset = max(geometry.safeAreaInsets.bottom, windowSafeAreaInsets.bottom)
            let expandedWidth = HomeQuickActionsFloatingMetrics.expandedWidth(
                for: geometry.size.width - MHBTheme.Spacing.s4 * 2
            )
            let expandedHeight = HomeQuickActionsFloatingMetrics.expandedHeight(
                actionCount: actions.count,
                availableHeight: geometry.size.height - effectiveBottomInset - 108
            )
            let surfaceState = HomeQuickActionsFloatingSurfaceState(
                progress: surfaceProgress,
                expandedWidth: expandedWidth,
                expandedHeight: expandedHeight
            )

            floatingContainer(surfaceState: surfaceState)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .background {
                MHBWindowSafeAreaReader { insets in
                    guard !windowSafeAreaInsets.mhb_isApproximatelyEqual(to: insets) else { return }
                    windowSafeAreaInsets = insets
                }
                .allowsHitTesting(false)
            }
        }
        .onAppear {
            isExpandedContentVisible = isPresented
            surfaceProgress = isPresented ? 1 : 0
        }
        .onChange(of: isPresented) { oldValue, newValue in
            withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
                surfaceProgress = newValue ? 1 : 0
            }
            updateExpandedContentVisibility(isPresented: newValue)
        }
    }

    private func floatingContainer(
        surfaceState: HomeQuickActionsFloatingSurfaceState
    ) -> some View {
        contentContainer(surfaceState: surfaceState)
        .frame(
            width: surfaceState.width,
            height: surfaceState.height,
            alignment: .topLeading
        )
        .glassEffect(
            .regular.interactive(),
            in: .rect(cornerRadius: surfaceState.cornerRadius)
        )
        .shadow(
            color: .black.opacity(0.12 + 0.06 * surfaceState.progress),
            radius: 12 + 8 * surfaceState.progress,
            y: 6 + 4 * surfaceState.progress
        )
    }

    private func contentContainer(
        surfaceState: HomeQuickActionsFloatingSurfaceState
    ) -> some View {
        collapsedToggle(surfaceState: surfaceState)
            .overlay(alignment: .topLeading) {
                expandedContent
                    .opacity(isExpandedContentVisible ? 1 : 0)
                    .allowsHitTesting(isPresented)
            }
        .clipped()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(isPresented ? "home.quickActions.panel" : "home.quickActions.floatingButton")
    }

    private func collapsedToggle(
        surfaceState: HomeQuickActionsFloatingSurfaceState
    ) -> some View {
        Button {
            isPresented = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .rotationEffect(.degrees(surfaceState.plusRotationDegrees))
                .frame(
                    width: HomeQuickActionsFloatingMetrics.collapsedSide,
                    height: HomeQuickActionsFloatingMetrics.collapsedSide
                )
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: isPresented ? .topTrailing : .center
        )
        .padding(.top, isPresented ? MHBTheme.Spacing.s2 : 0)
        .padding(.trailing, isPresented ? MHBTheme.Spacing.s2 : 0)
        .opacity(surfaceState.plusOpacity)
        .allowsHitTesting(!isPresented)
        .accessibilityLabel("展开快捷动作")
        .accessibilityIdentifier("home.quickActions.floatingButton")
    }

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
            HStack(spacing: MHBTheme.Spacing.s2) {
                Text("现在就做")
                    .font(MHBTheme.Typography.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.78))

                Spacer(minLength: MHBTheme.Spacing.s2)

                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white.opacity(0.88))
                        .frame(width: 32, height: 32)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("收起快捷动作")
            }
            .frame(height: HomeQuickActionsFloatingMetrics.headerHeight)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: HomeQuickActionsFloatingMetrics.rowSpacing) {
                    ForEach(Array(actions.enumerated()), id: \.element.id) { index, action in
                        actionRow(action, index: index)
                    }
                }
                .padding(.bottom, MHBTheme.Spacing.s1)
            }
        }
        .padding(MHBTheme.Spacing.s3)
    }

    @ViewBuilder
    private func actionRow(
        _ action: HomeDashboardSnapshot.Action,
        index: Int
    ) -> some View {
        let row = HomeQuickActionsFloatingRow(action: action)
            .opacity(isExpandedContentVisible ? 1 : 0)
            .offset(y: isExpandedContentVisible ? 0 : 14)
            .scaleEffect(isExpandedContentVisible ? 1 : 0.96, anchor: .bottomTrailing)
            .animation(
                .spring(response: 0.34, dampingFraction: 0.86)
                    .delay(0.03 * Double(index)),
                value: isExpandedContentVisible
            )

        if action.kind == .addReminder {
            Button {
                isPresented = false
                onAddReminder()
            } label: {
                row
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home.quickActions.panel.\(action.kind.rawValue)")
        } else if let route = HomeActionRouteResolver.route(
            for: action,
            context: routingContext
        ) {
            NavigationLink(value: route) {
                row
            }
            .buttonStyle(.plain)
            .simultaneousGesture(TapGesture().onEnded {
                isPresented = false
            })
            .accessibilityIdentifier("home.quickActions.panel.\(action.kind.rawValue)")
        } else {
            row
                .opacity(0.58)
                .accessibilityIdentifier("home.quickActions.panel.\(action.kind.rawValue).disabled")
        }
    }

    private func updateExpandedContentVisibility(isPresented: Bool) {
        if isPresented {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(110))
                guard self.isPresented else { return }
                isExpandedContentVisible = true
            }
        } else {
            isExpandedContentVisible = false
        }
    }
}
