import SwiftUI
import MaohuobanDesignSystem

// HomeQuickFactSingleChoiceSection 快捷事实单选分组
// 核心职责：
// - 承载 sheet 内单选标签集合
// - 以清晰选中态表达当前输入
struct HomeQuickFactSingleChoiceSection<Option: Identifiable & Equatable, Label: View>: View {
    let title: LocalizedStringResource
    let options: [Option]
    @Binding var selection: Option
    @ViewBuilder let label: (Option) -> Label

    var body: some View {
        HomeQuickFactSheetSection(title: title) {
            HomeQuickFactChoiceGrid(options: options) { option in
                HomeQuickFactSelectableChip(
                    isSelected: selection == option,
                    action: {
                        selection = option
                    }
                ) {
                    label(option)
                }
            }
        }
    }
}
