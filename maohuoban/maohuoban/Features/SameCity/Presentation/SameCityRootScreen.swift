import SwiftUI
import MaohuobanDesignSystem

// SameCityRootScreen 同城 Tab 根视图
// 核心职责：
// - 作为同城 Tab NavigationStack 的根内容
// - 承载本地服务入口和同城发布入口
struct SameCityRootScreen: View {
    var body: some View {
        ZStack {
            MHBTheme.ColorToken.background.color
                .ignoresSafeArea()

            VStack(spacing: MHBTheme.Spacing.s5) {
                SameCityRootHero()

                NavigationLink(
                    value: SameCityRoute.publishEvent(
                        PublishEntryContext(
                            source: .sameCity,
                            city: "成都",
                            localEntityName: "成都同城"
                        )
                    )
                ) {
                    SameCityPublishEntryLabel()
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("sameCity.publish.entry")
            }
            .padding(MHBTheme.Spacing.s5)
        }
        .navigationTitle("同城")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: SameCityRoute.self) { route in
            switch route {
            case .publishEvent(let context):
                PublishEventComposerScreen(context: context)
            }
        }
        .accessibilityIdentifier("sameCity.root")
    }
}

// SameCityRootHero 同城根页头部
// 核心职责：
// - 展示同城本地服务的当前阶段定位
// - 保持同城发布入口之外的根页信息稳定
private struct SameCityRootHero: View {
    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s4) {
            Image(systemName: "map.fill")
                .font(.system(size: MHBTheme.IconSize.tabRootPlaceholder))
                .foregroundStyle(MHBTheme.ColorToken.primary.color)

            Text("同城")
                .font(MHBTheme.Typography.title)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

            Text("本地服务 · 医院 / 猫舍 / 宠物店")
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

// SameCityPublishEntryLabel 同城发布入口标签
// 核心职责：
// - 提供从同城 Tab 进入图文发布页的主操作
// - 使用 Liquid Glass 强化跨页面发布入口
private struct SameCityPublishEntryLabel: View {
    var body: some View {
        Label("发布同城记录", systemImage: "square.and.pencil")
            .font(MHBTheme.Typography.callout.weight(.semibold))
            .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
            .padding(.horizontal, MHBTheme.Spacing.s5)
            .frame(height: MHBTheme.Spacing.s8 + MHBTheme.Spacing.s4)
            .glassEffect(.regular.interactive(), in: .capsule)
    }
}
