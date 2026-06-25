import SwiftUI
import MaohuobanDesignSystem

// PetPreventiveCareAddRecordPlaceholderSheet 新增疫苗驱虫占位弹层
// 核心职责：
// - 在快速 UI 阶段承接底部新增记录按钮
// - 为后续疫苗/驱虫真实记录表单预留原生 sheet 入口
struct PetPreventiveCareAddRecordPlaceholderSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s4) {
                Text("新增记录")
                    .font(MHBTheme.Typography.title.weight(.semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

                Text("这里后续会承载疫苗和驱虫的新增表单，包括类型、名称、完成日期、下次提醒、备注和照片。")
                    .font(MHBTheme.Typography.callout)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()
            }
            .padding(MHBTheme.Spacing.s5)
            .background(MHBTheme.ColorToken.background.color)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

