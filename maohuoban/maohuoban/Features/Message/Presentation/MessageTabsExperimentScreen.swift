import SwiftUI
import UIKit
import MaohuobanDesignSystem

// MessageTabsExperimentScreen tabs 布局实验页
// 核心职责：
// - 在页面内容流中验证 UIKit bridge tabs 基础设施
// - 观察多 tabs 横向滚动与选中项自动可见行为
struct MessageTabsExperimentScreen: View {
    @State private var contentSelection: MessageTabsExperimentTab = .experimentOne

    var body: some View {
        ZStack(alignment: .top) {
            MHBScreenScrollView {
                MessageTabsExperimentContentList(selection: contentSelection)
                .padding(.horizontal, MHBTheme.Spacing.s3)
                .padding(.top, MessageTabsExperimentLayout.fixedTabsReservedHeight)
                .padding(.bottom, MHBTheme.Spacing.s6)
            }

            MessageTabsExperimentFixedTabsOverlay(selection: $contentSelection)
                .zIndex(1)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("message.tabsExperiment.screen")
    }
}

// MessageTabsExperimentFixedTabsOverlay 内容流固定 tabs 容器
// 核心职责：
// - 将 UIKit bridge tabs 固定在滚动内容上方
// - 使用 SwiftUI Liquid Glass 容器遮挡滚动穿透
private struct MessageTabsExperimentFixedTabsOverlay: View {
    @Binding var selection: MessageTabsExperimentTab

    var body: some View {
        GeometryReader { proxy in
            let visibleWidth = MessageTabsExperimentLayout.visibleTabsWidth(for: proxy.size.width)

            HStack {
                ZStack {
                    Color.clear
                        .frame(
                            width: visibleWidth,
                            height: MessageTabsExperimentLayout.tabsHeight
                        )
                        .glassEffect(.regular.interactive(), in: .capsule)
                        .allowsHitTesting(false)

                    MessageTabsExperimentBridgeTabs(
                        selection: $selection,
                        accessibilityIdentifier: "message.tabsExperiment.contentPicker"
                    )
                    .frame(
                        width: visibleWidth,
                        height: MessageTabsExperimentLayout.tabsHeight
                    )
                }
                .frame(
                    width: visibleWidth,
                    height: MessageTabsExperimentLayout.tabsHeight
                )
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, MessageTabsExperimentLayout.fixedTabsTopPadding)
        }
        .frame(height: MessageTabsExperimentLayout.fixedTabsReservedHeight)
    }
}

// MessageTabsExperimentContentList tabs 实验滚动内容
// 核心职责：
// - 提供可滚动的纯文本内容用于观察固定 tabs 行为
// - 避免卡片、材质或额外背景干扰系统控件视觉
private struct MessageTabsExperimentContentList: View {
    let selection: MessageTabsExperimentTab

    var body: some View {
        let items = MessageTabsExperimentContentItem.items(for: selection)

        LazyVStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
            ForEach(items) { item in
                MessageTabsExperimentContentRow(item: item)

                if item.id != items.last?.id {
                    Divider()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MessageTabsExperimentContentRow tabs 实验内容行
// 核心职责：
// - 以无背景文本行展示滚动内容
// - 保持足够高度方便真机观察固定 tabs 与滚动内容关系
private struct MessageTabsExperimentContentRow: View {
    let item: MessageTabsExperimentContentItem

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
            Text(item.title)
                .font(MHBTheme.Typography.headline)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

            Text(item.subtitle)
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                .fixedSize(horizontal: false, vertical: true)

            Text(item.metadata)
                .font(MHBTheme.Typography.caption)
                .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, MHBTheme.Spacing.s2)
    }
}

// MessageTabsExperimentBridgeTabs UIKit bridge tabs 选择器
// 核心职责：
// - 使用原生 UISegmentedControl 渲染多个实验选项
// - 为 toolbar 与内容流提供一致的固定尺寸
// - 使用主题色验证选中填充配置
// - 将选中项回写给调用方状态
private struct MessageTabsExperimentBridgeTabs: View {
    @Binding var selection: MessageTabsExperimentTab
    let accessibilityIdentifier: String

    var body: some View {
        MHBToolbarLikeSegmentedTabs(
            items: MessageTabsExperimentTab.allCases.map { tab in
                MHBToolbarLikeSegmentedTabs<MessageTabsExperimentTab>.Item(
                    selection: tab,
                    title: tab.title
                )
            },
            selection: $selection,
            segmentWidth: MessageTabsExperimentLayout.segmentWidth,
            height: MessageTabsExperimentLayout.tabsHeight,
            selectedSegmentTintColor: MHBTheme.ColorToken.primary.uiColor,
            normalTitleColor: MHBTheme.ColorToken.labelPrimary.uiColor,
            selectedTitleColor: MessageTabsExperimentColors.selectedTitle,
            accessibilityIdentifier: accessibilityIdentifier
        )
    }
}

// MessageTabsExperimentContentItem tabs 实验内容项
// 核心职责：
// - 生成本地 mock 文本内容
// - 按当前 tabs 选中项提供不同文案便于验证切换
private struct MessageTabsExperimentContentItem: Identifiable {
    let id: Int
    let title: String
    let subtitle: String
    let metadata: String

    static func items(for tab: MessageTabsExperimentTab) -> [MessageTabsExperimentContentItem] {
        (1...24).map { index in
            MessageTabsExperimentContentItem(
                id: index,
                title: "\(tab.title) 内容 \(index)",
                subtitle: "这是一条用于观察滚动、固定 tabs 和系统控件视觉关系的占位内容。当前内容没有卡片背景，也没有额外材质。",
                metadata: "消息实验 · 第 \(index) 条"
            )
        }
    }
}

// MessageTabsExperimentTab tabs 实验选项
// 核心职责：
// - 定义导航栏与内容流实验复用的两个选项
// - 提供稳定身份和值语义
private enum MessageTabsExperimentTab: CaseIterable, Identifiable, Hashable {
    case experimentOne
    case experimentTwo
    case experimentThree
    case experimentFour
    case experimentFive
    case experimentSix
    case experimentSeven
    case experimentEight

    var id: Self { self }

    var title: String {
        switch self {
        case .experimentOne: "实验 1"
        case .experimentTwo: "实验 2"
        case .experimentThree: "实验 3"
        case .experimentFour: "实验 4"
        case .experimentFive: "实验 5"
        case .experimentSix: "实验 6"
        case .experimentSeven: "实验 7"
        case .experimentEight: "实验 8"
        }
    }
}

// MessageTabsExperimentLayout tabs 实验布局参数
// 核心职责：
// - 统一导航栏与内容流 bridge tabs 的固定尺寸
// - 暴露真机调试时可快速调整的实验参数
private enum MessageTabsExperimentLayout {
    static let segmentWidth: CGFloat = 72
    static let tabsHeight: CGFloat = 44
    static let fixedTabsHorizontalInset: CGFloat = MHBTheme.Spacing.s3
    static let fixedTabsTopPadding: CGFloat = MHBTheme.Spacing.s3
    static let fixedTabsBottomSpacing: CGFloat = MHBTheme.Spacing.s4

    static var fixedTabsReservedHeight: CGFloat {
        fixedTabsTopPadding + tabsHeight + fixedTabsBottomSpacing
    }

    static func visibleTabsWidth(for screenWidth: CGFloat) -> CGFloat {
        max(0, screenWidth - fixedTabsHorizontalInset * 2)
    }
}

// MessageTabsExperimentColors tabs 实验颜色配置
// 核心职责：
// - 保持选中填充使用主题色
// - 为主题填充上的文字提供浅深色都稳定的对比度
private enum MessageTabsExperimentColors {
    static let selectedTitle = UIColor { traits in
        let token = traits.userInterfaceStyle == .dark
            ? MHBTheme.ColorToken.labelPrimary
            : MHBTheme.ColorToken.cardSolid

        return token.mhb_resolvedUIColor(for: traits)
    }
}

private extension MHBTheme.ColorToken {
    func mhb_resolvedUIColor(for traits: UITraitCollection) -> UIColor {
        if traits.userInterfaceStyle == .dark {
            return UIColor(red: darkRed, green: darkGreen, blue: darkBlue, alpha: darkAlpha)
        }

        return UIColor(red: red, green: green, blue: blue, alpha: alpha)
    }
}
