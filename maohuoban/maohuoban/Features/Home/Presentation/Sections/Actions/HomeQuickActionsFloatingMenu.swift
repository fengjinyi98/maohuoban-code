import SwiftUI
import MaohuobanDesignSystem

// HomeQuickActionsFloatingMenu 首页快捷动作浮动菜单
// 核心职责：
// - 在首页右下角固定承载快捷动作入口
// - 使用 Liquid Glass 展示可展开的动作面板
struct HomeQuickActionsFloatingMenu: View {
    let actions: [HomeDashboardSnapshot.Action]
    let routingContext: HomeActionRoutingContext
    @Binding var isPresented: Bool
    let onAddReminder: () -> Void

    var body: some View {
        GlassEffectContainer(spacing: MHBTheme.Spacing.s3) {
            ZStack(alignment: .bottomTrailing) {
                MHBAnchoredFloatingPanel(
                    isPresented: isPresented,
                    offset: CGSize(width: 0, height: -70),
                    scaleAnchor: .bottomTrailing
                ) {
                    HomeQuickActionsFloatingPanel(
                        actions: actions,
                        routingContext: routingContext,
                        isPresented: $isPresented,
                        onAddReminder: onAddReminder
                    )
                }

                HomeQuickActionsFloatingButton(isPresented: $isPresented)
            }
        }
        .animation(.snappy(duration: 0.24), value: isPresented)
    }
}

// HomeQuickActionsFloatingButton 首页快捷动作浮动按钮
// 核心职责：
// - 固定展示快捷动作入口
// - 控制快捷动作面板展开与收起
private struct HomeQuickActionsFloatingButton: View {
    @Binding var isPresented: Bool

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            Image(systemName: isPresented ? "xmark" : "plus")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 58, height: 58)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .capsule)
        .accessibilityLabel(isPresented ? "收起快捷动作" : "展开快捷动作")
        .accessibilityIdentifier("home.quickActions.floatingButton")
    }
}

// HomeQuickActionsFloatingPanel 首页快捷动作浮动面板
// 核心职责：
// - 展示当前首页上下文可用动作
// - 保持动作展示与导航有效性解耦
private struct HomeQuickActionsFloatingPanel: View {
    let actions: [HomeDashboardSnapshot.Action]
    let routingContext: HomeActionRoutingContext
    @Binding var isPresented: Bool
    let onAddReminder: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
            ForEach(actions) { action in
                if action.kind == .addReminder {
                    Button {
                        isPresented = false
                        onAddReminder()
                    } label: {
                        HomeQuickActionsFloatingRow(action: action, isEnabled: true)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("home.quickActions.panel.\(action.kind.rawValue)")
                } else if let route = HomeActionRouteResolver.route(
                    for: action,
                    context: routingContext
                ) {
                    NavigationLink(value: route) {
                        HomeQuickActionsFloatingRow(action: action, isEnabled: true)
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(TapGesture().onEnded {
                        isPresented = false
                    })
                    .accessibilityIdentifier("home.quickActions.panel.\(action.kind.rawValue)")
                } else {
                    HomeQuickActionsFloatingRow(action: action, isEnabled: false)
                        .accessibilityIdentifier("home.quickActions.panel.\(action.kind.rawValue).disabled")
                }
            }
        }
        .padding(MHBTheme.Spacing.s3)
        .frame(width: 214)
        .glassEffect(.regular, in: .rect(cornerRadius: MHBTheme.Radius.large))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.quickActions.panel")
    }
}

// HomeQuickActionsFloatingRow 首页快捷动作浮动行
// 核心职责：
// - 展示面板中的单个快捷动作
// - 呈现动作可用与不可用状态
private struct HomeQuickActionsFloatingRow: View {
    let action: HomeDashboardSnapshot.Action
    let isEnabled: Bool

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s3) {
            Image(systemName: HomeQuickActionIcon.name(for: action.kind))
                .font(.system(size: MHBTheme.IconSize.small, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(.white.opacity(isEnabled ? 0.18 : 0.08))
                .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.small, style: .continuous))

            Text(action.title)
                .font(MHBTheme.Typography.footnote)
                .foregroundStyle(.white.opacity(isEnabled ? 0.96 : 0.44))
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: MHBTheme.Spacing.s2)
        }
        .padding(.horizontal, MHBTheme.Spacing.s2)
        .padding(.vertical, MHBTheme.Spacing.s2)
        .contentShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
        .opacity(isEnabled ? 1 : 0.56)
    }
}

// HomeQuickActionIcon 首页快捷动作图标映射
// 核心职责：
// - 统一维护快捷动作类型到系统图标的映射
// - 让卡片与浮动面板复用同一套图标语义
private enum HomeQuickActionIcon {
    static func name(for kind: HomeDashboardSnapshot.Action.Kind) -> String {
        switch kind {
        case .createPet: "plus.circle.fill"
        case .dailyRecord: "square.and.pencil"
        case .walk: "figure.walk"
        case .healthRecord: "stethoscope"
        case .preventiveCare: "syringe"
        case .addReminder: "bell.badge.fill"
        case .bookHospital: "stethoscope"
        case .importTradePet: "tray.and.arrow.down.fill"
        case .addMerchantPet: "pawprint.circle.fill"
        case .publishAvailableStatus: "tag.fill"
        }
    }
}
