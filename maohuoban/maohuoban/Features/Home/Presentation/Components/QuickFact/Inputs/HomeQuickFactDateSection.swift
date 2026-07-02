import SwiftUI
import MaohuobanDesignSystem

// HomeQuickFactDateSection 快捷事实时间选择区
// 核心职责：
// - 收集快捷记录的真实发生时间
// - 统一喂食和异常 sheet 的时间输入样式
struct HomeQuickFactDateSection: View {
    let title: LocalizedStringResource
    @Binding var date: Date

    var body: some View {
        HomeQuickFactSheetSection(title: title) {
            DatePicker(
                "发生时间",
                selection: $date,
                displayedComponents: [.date, .hourAndMinute]
            )
            .font(MHBTheme.Typography.callout)
            .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
            .padding(MHBTheme.Spacing.s4)
            .background(MHBTheme.ColorToken.cardSolid.color)
            .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.extraLarge, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: MHBTheme.Radius.extraLarge, style: .continuous)
                    .stroke(MHBTheme.ColorToken.separator.color, lineWidth: 1)
            }
        }
    }
}
