import SwiftUI
import MaohuobanDesignSystem

// PetDietTrendDetailEvidenceRow 饮食趋势证据行
// 核心职责：
// - 展示单条数据依据
// - 使用稳定点状标记保持列表可扫读
struct PetDietTrendDetailEvidenceRow: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: MHBTheme.Spacing.s2) {
            Circle()
                .fill(MHBTheme.ColorToken.primary.color)
                .frame(width: 5, height: 5)
                .padding(.top, 7)

            Text(text)
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

