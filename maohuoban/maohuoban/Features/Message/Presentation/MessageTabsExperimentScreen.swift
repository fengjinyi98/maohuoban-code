import SwiftUI
import MaohuobanDesignSystem

// MessageTabsExperimentScreen 官方 tabs 布局实验页
// 核心职责：
// - 在系统导航栏区域承载官方 tabs Picker
// - 在页面内容流中承载同样的官方 tabs Picker
struct MessageTabsExperimentScreen: View {
    @State private var navigationSelection: MessageTabsExperimentTab = .experimentOne
    @State private var contentSelection: MessageTabsExperimentTab = .experimentOne

    var body: some View {
        ZStack {
            MHBTheme.ColorToken.background.color
                .ignoresSafeArea()

            MHBScreenScrollView {
                VStack(spacing: MHBTheme.Spacing.s4) {
                    MessageTabsExperimentPicker(
                        title: "内容流 tabs",
                        selection: $contentSelection
                    )
                    .accessibilityIdentifier("message.tabsExperiment.contentPicker")

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
                MessageTabsExperimentPicker(
                    title: "导航栏 tabs",
                    selection: $navigationSelection
                )
                .accessibilityIdentifier("message.tabsExperiment.navigationPicker")
            }
        }
        .accessibilityIdentifier("message.tabsExperiment.screen")
    }
}

// MessageTabsExperimentPicker 官方 tabs 选择器
// 核心职责：
// - 使用 SwiftUI 官方 tabs Picker 样式渲染两个实验选项
// - 将选中项回写给调用方状态
private struct MessageTabsExperimentPicker: View {
    let title: LocalizedStringResource
    @Binding var selection: MessageTabsExperimentTab

    var body: some View {
        Picker(title, selection: $selection) {
            ForEach(MessageTabsExperimentTab.allCases) { tab in
                Text(tab.title)
                    .tag(tab)
            }
        }
        .pickerStyle(.tabs)
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

    var title: LocalizedStringResource {
        switch self {
        case .experimentOne: "实验 1"
        case .experimentTwo: "实验 2"
        }
    }
}
