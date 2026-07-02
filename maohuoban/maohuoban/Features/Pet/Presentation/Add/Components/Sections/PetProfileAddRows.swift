import SwiftUI
import MaohuobanDesignSystem

// PetProfileAddSection 添加宠物资料分组
// 核心职责：
// - 承载添加档案页面的一组 row
// - 复刻编辑档案页的卡片分组样式
struct PetProfileAddSection<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            content()
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
    }
}

// PetProfileAddRow 添加宠物资料通用行
// 核心职责：
// - 展示字段名、字段值和进入提示
// - 保持添加页与编辑页 row 高度一致
struct PetProfileAddRow<Value: View>: View {
    let title: String
    let showsSeparator: Bool
    let isAccessoryExpanded: Bool
    let action: () -> Void
    @ViewBuilder let value: () -> Value

    init(
        title: String,
        showsSeparator: Bool = true,
        isAccessoryExpanded: Bool = false,
        action: @escaping () -> Void = {},
        @ViewBuilder value: @escaping () -> Value
    ) {
        self.title = title
        self.showsSeparator = showsSeparator
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
                        .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)

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

// PetProfileAddValueText 添加宠物资料行值文本
// 核心职责：
// - 统一添加页 row 右侧文本样式
// - 对占位内容应用弱化颜色
struct PetProfileAddValueText: View {
    let value: String

    var body: some View {
        let isPlaceholder = value.isEmpty || value == "未添加" || value == "未设置" || value == "暂无" || value == "暂未记录"
        Text(value)
            .font(.system(size: 16, weight: .regular))
            .foregroundStyle(isPlaceholder ? MHBTheme.ColorToken.labelTertiary.color : MHBTheme.ColorToken.labelPrimary.color)
            .lineLimit(1)
            .truncationMode(.tail)
    }
}

// PetProfileAddTagFlow 添加宠物性格标签展示
// 核心职责：
// - 在资料 row 中展示已选性格标签
// - 复用设计系统标签组件保持视觉一致
struct PetProfileAddTagFlow: View {
    let tags: [String]

    var body: some View {
        if tags.isEmpty {
            PetProfileAddValueText(value: "暂未设置")
        } else {
            HStack(spacing: MHBTheme.Spacing.s1) {
                ForEach(tags.prefix(3), id: \.self) { tag in
                    MHBTagView(tag, style: .neutral, size: .small)
                }
            }
        }
    }
}
