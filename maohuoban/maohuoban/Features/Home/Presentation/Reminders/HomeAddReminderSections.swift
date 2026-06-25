import SwiftUI
import MaohuobanDesignSystem

// HomeReminderTitleSection 提醒标题输入区
// 核心职责：
// - 收集提醒本体标题
// - 让快捷类型可以在未编辑标题时提供默认文案
struct HomeReminderTitleSection: View {
    @Binding var titleText: String
    var isTitleFocused: FocusState<Bool>.Binding

    var body: some View {
        HomeReminderFormSection(title: "提醒内容") {
            TextField("例如 复诊、剪指甲、买粮", text: $titleText)
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused(isTitleFocused)
        }
    }
}

// HomeReminderKindSection 提醒类型选择区
// 核心职责：
// - 提供常见提醒类型快捷选择
// - 通过方形圆角标签表达选中态
struct HomeReminderKindSection: View {
    @Binding var selectedKind: HomeReminderDraftKind
    let onSelectKind: (HomeReminderDraftKind) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: MHBTheme.Spacing.s2),
        GridItem(.flexible(), spacing: MHBTheme.Spacing.s2)
    ]

    var body: some View {
        HomeReminderFormSection(title: "类型") {
            LazyVGrid(columns: columns, spacing: MHBTheme.Spacing.s2) {
                ForEach(HomeReminderDraftKind.allCases) { kind in
                    HomeReminderKindButton(
                        kind: kind,
                        isSelected: selectedKind == kind,
                        action: {
                            onSelectKind(kind)
                        }
                    )
                }
            }
        }
    }
}

// HomeReminderKindButton 提醒类型按钮
// 核心职责：
// - 展示单个提醒类型图标和标题
// - 表达当前选中态
private struct HomeReminderKindButton: View {
    let kind: HomeReminderDraftKind
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: MHBTheme.Spacing.s2) {
                Image(systemName: kind.systemImage)
                    .font(.system(size: 15, weight: .semibold))

                Text(kind.title)
                    .font(MHBTheme.Typography.callout.weight(.semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? MHBTheme.ColorToken.primary.color : MHBTheme.ColorToken.labelSecondary.color)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(
                isSelected ? MHBTheme.ColorToken.primary.color.opacity(0.12) : MHBTheme.ColorToken.labelQuaternary.color.opacity(0.24),
                in: RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous)
                    .stroke(isSelected ? MHBTheme.ColorToken.primary.color : MHBTheme.ColorToken.separatorSoft.color, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

// HomeReminderDateSection 提醒时间选择区
// 核心职责：
// - 收集提醒到期日期和时间
// - 使用系统 DatePicker 保持输入稳定
struct HomeReminderDateSection: View {
    @Binding var dueAt: Date

    var body: some View {
        HomeReminderFormSection(title: "时间") {
            DatePicker(
                "提醒时间",
                selection: $dueAt,
                displayedComponents: [.date, .hourAndMinute]
            )
            .font(MHBTheme.Typography.callout)
            .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
        }
    }
}

// HomeReminderAdvanceNoticeSection 提前提醒选择区
// 核心职责：
// - 展示提前提醒时间选项
// - 为提醒系统 advanceNotice 字段提供 UI 输入
struct HomeReminderAdvanceNoticeSection: View {
    @Binding var selection: HomeReminderAdvanceNotice

    private let columns = [
        GridItem(.flexible(), spacing: MHBTheme.Spacing.s2),
        GridItem(.flexible(), spacing: MHBTheme.Spacing.s2)
    ]

    var body: some View {
        HomeReminderFormSection(title: "提前提醒") {
            LazyVGrid(columns: columns, spacing: MHBTheme.Spacing.s2) {
                ForEach(HomeReminderAdvanceNotice.allCases) { option in
                    HomeReminderOptionButton(
                        title: option.title,
                        isSelected: selection == option,
                        action: {
                            selection = option
                        }
                    )
                }
            }
        }
    }
}

// HomeReminderOptionButton 提醒单选按钮
// 核心职责：
// - 展示提醒配置单选项
// - 保持提前提醒选项视觉一致
private struct HomeReminderOptionButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(MHBTheme.Typography.callout.weight(.semibold))
                .foregroundStyle(isSelected ? MHBTheme.ColorToken.primary.color : MHBTheme.ColorToken.labelSecondary.color)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    isSelected ? MHBTheme.ColorToken.primary.color.opacity(0.12) : MHBTheme.ColorToken.labelQuaternary.color.opacity(0.24),
                    in: RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous)
                )
        }
        .buttonStyle(.plain)
    }
}

// HomeReminderNoteSection 提醒备注输入区
// 核心职责：
// - 收集提醒补充说明
// - 支持复诊说明、用药剂量和购买事项等自由文本
struct HomeReminderNoteSection: View {
    @Binding var note: String

    var body: some View {
        HomeReminderFormSection(title: "备注") {
            TextField("例如 带上上次检查单、晚饭后用药", text: $note, axis: .vertical)
                .lineLimit(3...5)
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// HomeReminderFormSection 添加提醒表单分组
// 核心职责：
// - 统一提醒表单标题、卡片和间距
// - 让 sheet 内容与现有记录表单视觉保持一致
private struct HomeReminderFormSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
            Text(title)
                .font(MHBTheme.Typography.callout.weight(.semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)

            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .padding(MHBTheme.Spacing.s4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MHBTheme.ColorToken.cardSolid.color)
            .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
        }
    }
}
