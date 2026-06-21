import SwiftUI
import MaohuobanDesignSystem

// PetHealthRecordContent 健康记录页面内容
// 核心职责：
// - 组合宠物身份、健康类型、表单详情和提醒设置
// - 通过窄 Binding 将用户输入回传给提交层
struct PetHealthRecordContent: View {
    let petID: String?
    let petSex: PetRecordPetSex
    @Binding var selectedType: PetHealthRecordType
    @Binding var occurredAt: Date
    @Binding var weightText: String
    @Binding var vaccineBrand: String
    @Binding var vaccineDose: String
    @Binding var visitReason: String
    @Binding var note: String
    @Binding var reminderEnabled: Bool
    @Binding var reminderDate: Date

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s4) {
            PetRecordPetIdentityCard(
                petID: petID,
                petSex: petSex,
                description: "正在为它添加健康记录"
            )
            PetHealthTypeGrid(selectedType: $selectedType)
            PetHealthCoreFormSection(
                selectedType: selectedType,
                occurredAt: $occurredAt,
                weightText: $weightText
            )
            PetHealthDetailFormSection(
                selectedType: selectedType,
                vaccineBrand: $vaccineBrand,
                vaccineDose: $vaccineDose,
                visitReason: $visitReason,
                note: $note
            )
            PetHealthReminderSection(
                reminderEnabled: $reminderEnabled,
                reminderDate: $reminderDate
            )
            PetHealthTrustHint()
        }
    }
}

// PetHealthTypeGrid 健康类型选择宫格
// 核心职责：
// - 展示疫苗、驱虫、就诊和体重四类健康记录入口
// - 通过明确按钮状态表达当前选中类型
private struct PetHealthTypeGrid: View {
    @Binding var selectedType: PetHealthRecordType

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: MHBTheme.Spacing.s3),
        count: 4
    )

    var body: some View {
        LazyVGrid(columns: columns, spacing: MHBTheme.Spacing.s3) {
            ForEach(PetHealthRecordType.allCases) { type in
                PetHealthTypeButton(
                    type: type,
                    isSelected: selectedType == type
                ) {
                    selectedType = type
                }
            }
        }
        .padding(.vertical, MHBTheme.Spacing.s1)
    }
}

// PetHealthTypeButton 健康类型按钮
// 核心职责：
// - 承载单个健康类型的图标和标题
// - 维持选中态、点击区域和无障碍语义稳定
private struct PetHealthTypeButton: View {
    let type: PetHealthRecordType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: MHBTheme.Spacing.s2) {
                ZStack {
                    Image(systemName: type.systemImage)
                        .font(.system(size: 26, weight: .medium))
                        .foregroundStyle(isSelected ? healthAccentColor : MHBTheme.ColorToken.labelSecondary.color)
                }
                .frame(width: 68, height: 68)
                .background(
                    isSelected ? healthAccentColor.opacity(0.12) : MHBTheme.ColorToken.labelQuaternary.color.opacity(0.3),
                    in: RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous)
                        .stroke(
                            isSelected ? healthAccentColor.opacity(0.45) : Color.clear,
                            lineWidth: 2
                        )
                }

                Text(type.displayName)
                    .font(MHBTheme.Typography.caption.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? MHBTheme.ColorToken.labelPrimary.color : MHBTheme.ColorToken.labelSecondary.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(type.displayName)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// PetHealthCoreFormSection 健康基础信息区
// 核心职责：
// - 收集健康事件发生时间
// - 支持在任意健康类型中顺带记录体重
private struct PetHealthCoreFormSection: View {
    let selectedType: PetHealthRecordType
    @Binding var occurredAt: Date
    @Binding var weightText: String

    var body: some View {
        PetHealthFormCard {
            DatePicker(
                "日期",
                selection: $occurredAt,
                displayedComponents: [.date, .hourAndMinute]
            )
            .font(MHBTheme.Typography.callout)
            .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

            PetHealthDivider()

            PetHealthTextInputRow(
                title: selectedType == .weight ? "当前体重" : "顺便记体重",
                systemImage: "scalemass",
                text: $weightText,
                prompt: "输入当前体重 kg",
                keyboardType: .decimalPad
            )
        }
    }
}

// PetHealthDetailFormSection 健康详情表单区
// 核心职责：
// - 根据健康类型展示对应的详情输入
// - 收集备注信息用于生成事件摘要
private struct PetHealthDetailFormSection: View {
    let selectedType: PetHealthRecordType
    @Binding var vaccineBrand: String
    @Binding var vaccineDose: String
    @Binding var visitReason: String
    @Binding var note: String

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
            Text(selectedType.detailTitle)
                .font(MHBTheme.Typography.section)
                .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
                .textCase(.uppercase)

            PetHealthFormCard {
                switch selectedType {
                case .vaccine:
                    PetHealthTextInputRow(
                        title: "疫苗品牌",
                        text: $vaccineBrand,
                        prompt: "例如 妙三多"
                    )
                    PetHealthDivider()
                    PetHealthTextInputRow(
                        title: "打针针次",
                        text: $vaccineDose,
                        prompt: "例如 第 3 针"
                    )
                case .deworming:
                    PetHealthTextInputRow(
                        title: "驱虫方案",
                        text: $vaccineBrand,
                        prompt: "例如 内外同驱"
                    )
                case .visit:
                    PetHealthTextInputRow(
                        title: "就诊原因",
                        text: $visitReason,
                        prompt: "例如 复查、腹泻观察"
                    )
                case .weight:
                    Text("体重会写入本次健康时间线，用于后续趋势观察。")
                        .font(MHBTheme.Typography.callout)
                        .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                }

                PetHealthDivider()

                PetHealthMultilineInput(
                    title: "备注",
                    text: $note,
                    prompt: "补充精神、食欲、医嘱或观察结果"
                )

                PetHealthDivider()

                PetHealthProofUploader()
            }
        }
    }
}

// PetHealthReminderSection 健康提醒设置区
// 核心职责：
// - 控制是否为本次健康记录生成后续提醒语义
// - 在开启提醒时收集下一次提醒日期
private struct PetHealthReminderSection: View {
    @Binding var reminderEnabled: Bool
    @Binding var reminderDate: Date

    var body: some View {
        PetHealthFormCard {
            Toggle(isOn: $reminderEnabled) {
                Label("开启下次提醒", systemImage: "bell")
                    .font(MHBTheme.Typography.callout)
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
            }
            .tint(healthAccentColor)

            if reminderEnabled {
                PetHealthDivider()
                DatePicker(
                    "提醒日期",
                    selection: $reminderDate,
                    displayedComponents: [.date]
                )
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
            }
        }
    }
}

// PetHealthTrustHint 健康信任提示
// 核心职责：
// - 说明凭证和完整记录对健康档案的价值
// - 强化记录行为与宠物可信档案的关联
private struct PetHealthTrustHint: View {
    var body: some View {
        HStack(alignment: .top, spacing: MHBTheme.Spacing.s3) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: MHBTheme.IconSize.small, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.warning.color)

            Text("完整记录凭证将提升宠物健康档案可信度，保存后会同步到当前宠物时间线。")
                .font(MHBTheme.Typography.caption)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(MHBTheme.Spacing.s4)
        .background(MHBTheme.ColorToken.warning.color.opacity(0.10), in: .rect(cornerRadius: MHBTheme.Radius.large))
    }
}

private var healthAccentColor: Color {
    MHBTheme.ColorToken.success.color
}
