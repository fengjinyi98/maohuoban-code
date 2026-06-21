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
        ZStack {
            MHBTheme.ColorToken.background.color
                .ignoresSafeArea()

            MHBScreenScrollView {
                VStack(spacing: MHBTheme.Spacing.s4) {
                    MessageTabsExperimentBridgeTabs(
                        selection: $contentSelection,
                        accessibilityIdentifier: "message.tabsExperiment.contentPicker",
                        debugContext: "content"
                    )

                    Color.clear
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 520)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, MHBTheme.Spacing.s3)
                .padding(.top, MHBTheme.Spacing.s3)
                .padding(.bottom, MHBTheme.Spacing.s6)
            }
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
            width: MessageTabsExperimentLayout.tabsWidth,
            height: MessageTabsExperimentLayout.tabsHeight
        )
    }
}

// MessageTabsExperimentTab tabs 实验选项
// 核心职责：
// - 定义导航栏与内容流实验复用的两个选项
// - 提供稳定身份和值语义
private enum MessageTabsExperimentTab: CaseIterable, Identifiable, Hashable {
    case experimentOne
    case experimentTwo

    var id: Self { self }

    var title: String {
        switch self {
        case .experimentOne: "实验 1"
        case .experimentTwo: "实验 2"
        }
    }
}

// MessageTabsExperimentLayout tabs 实验布局参数
// 核心职责：
// - 统一导航栏与内容流 bridge tabs 的固定尺寸
// - 暴露真机调试时可快速调整的实验参数
private enum MessageTabsExperimentLayout {
    static let segmentWidth: CGFloat = 64
    static let tabsHeight: CGFloat = 44

    static var tabsWidth: CGFloat {
        CGFloat(MessageTabsExperimentTab.allCases.count) * segmentWidth
    }
}
