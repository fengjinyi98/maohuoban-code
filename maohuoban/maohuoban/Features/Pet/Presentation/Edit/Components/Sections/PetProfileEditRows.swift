import SwiftUI
import MaohuobanDesignSystem
import UIKit

// PetProfileEditSection 编辑资料分组卡片
// 核心职责：
// - 承载一组资料编辑行
// - 统一卡片背景、圆角和分割线策略
struct PetProfileEditSection<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            content()
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
    }
}

// PetProfileEditRow 编辑资料通用行
// 核心职责：
// - 展示左侧字段名、右侧字段值和可进入提示
// - 保持各字段行高与分割线一致
struct PetProfileEditRow<Value: View>: View {
    let title: String
    let showsSeparator: Bool
    let titleColor: Color
    let isAccessoryExpanded: Bool
    let action: () -> Void
    @ViewBuilder let value: () -> Value

    init(
        title: String,
        showsSeparator: Bool = true,
        titleColor: Color = MHBTheme.ColorToken.labelSecondary.color,
        isAccessoryExpanded: Bool = false,
        action: @escaping () -> Void = {},
        @ViewBuilder value: @escaping () -> Value
    ) {
        self.title = title
        self.showsSeparator = showsSeparator
        self.titleColor = titleColor
        self.isAccessoryExpanded = isAccessoryExpanded
        self.action = action
        self.value = value
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                HStack(spacing: MHBTheme.Spacing.s2) {
                    Text(title)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(titleColor)

                    Spacer(minLength: MHBTheme.Spacing.s3)

                    value()
                        .frame(maxWidth: .infinity, alignment: .trailing)

                    MHBAnimatedDisclosureChevron(isExpanded: isAccessoryExpanded)
                }
                .padding(.horizontal, MHBTheme.Spacing.s4)
                .frame(minHeight: 52)
                .contentShape(Rectangle())

                if showsSeparator {
                    Rectangle()
                        .fill(MHBTheme.ColorToken.separatorSoft.color)
                        .frame(height: 0.5)
                        .padding(.horizontal, MHBTheme.Spacing.s4)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
