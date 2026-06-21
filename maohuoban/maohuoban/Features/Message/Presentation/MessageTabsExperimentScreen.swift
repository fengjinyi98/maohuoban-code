import SwiftUI
import MaohuobanDesignSystem

// MessageTabsExperimentScreen tabs 布局实验页
// 核心职责：
// - 在系统导航栏区域承载 UIKit bridge tabs
// - 在页面内容流中承载同样尺寸的 UIKit bridge tabs
struct MessageTabsExperimentScreen: View {
    @State private var navigationSelection: MessageTabsExperimentTab = .experimentOne
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
        .toolbar {
            ToolbarItem(placement: .principal) {
                MessageTabsExperimentBridgeTabs(
                    selection: $navigationSelection,
                    accessibilityIdentifier: "message.tabsExperiment.navigationPicker",
                    debugContext: "toolbar"
                )
            }
        }
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
        MessageTabsExperimentBridgeTabs(
            selection: $selection,
            accessibilityIdentifier: "message.tabsExperiment.contentPicker",
            debugContext: "content"
        )
        .glassEffect(.regular.interactive(), in: .capsule)
        .padding(.top, MessageTabsExperimentLayout.fixedTabsTopPadding)
        .onAppear {
            print("[DEBUG:TabsBridge] fixedOverlay glass=regularInteractive shape=capsule visibleWidth=\(MessageTabsExperimentLayout.visibleTabsWidth.mhb_tabsExperimentFormattedValue) contentWidth=\(MessageTabsExperimentLayout.tabsWidth.mhb_tabsExperimentFormattedValue) height=\(MessageTabsExperimentLayout.tabsHeight.mhb_tabsExperimentFormattedValue) topPadding=\(MessageTabsExperimentLayout.fixedTabsTopPadding.mhb_tabsExperimentFormattedValue)")
        }
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
// - 使用原生 UISegmentedControl 渲染两个实验选项
// - 为 toolbar 与内容流提供一致的固定尺寸
// - 将选中项回写给调用方状态
private struct MessageTabsExperimentBridgeTabs: View {
    @Binding var selection: MessageTabsExperimentTab
    let accessibilityIdentifier: String
    let debugContext: String

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
            accessibilityIdentifier: accessibilityIdentifier,
            debugContext: debugContext
        )
        .frame(
            width: MessageTabsExperimentLayout.visibleTabsWidth,
            height: MessageTabsExperimentLayout.tabsHeight
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
    static let visibleTabsWidth: CGFloat = 260
    static let fixedTabsTopPadding: CGFloat = MHBTheme.Spacing.s3
    static let fixedTabsBottomSpacing: CGFloat = MHBTheme.Spacing.s4

    static var fixedTabsReservedHeight: CGFloat {
        fixedTabsTopPadding + tabsHeight + fixedTabsBottomSpacing
    }

    static var tabsWidth: CGFloat {
        CGFloat(MessageTabsExperimentTab.allCases.count) * segmentWidth
    }
}

private extension CGFloat {
    var mhb_tabsExperimentFormattedValue: String {
        String(format: "%.1f", self)
    }
}
