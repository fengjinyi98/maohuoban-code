import SwiftUI
import MaohuobanDesignSystem

// PetDailyRecordContent 日常记录页面内容
// 核心职责：
// - 组合宠物、时间、精神状态、饮食排泄、运动护理和备注输入
// - 通过 Binding 将日常打卡状态回传给提交层
struct PetDailyRecordContent: View {
    let petID: String?
    let petSex: PetRecordPetSex
    @Binding var occurredAt: Date
    @Binding var energy: PetDailyRecordEnergy
    @Binding var didFeed: Bool
    @Binding var foodText: String
    @Binding var didCleanPoop: Bool
    @Binding var poopStatus: PetDailyRecordPoopStatus
    @Binding var didAddWater: Bool
    @Binding var didBath: Bool
    @Binding var note: String

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s4) {
            PetDailyHeaderSection(
                petID: petID,
                petSex: petSex,
                occurredAt: $occurredAt
            )
            PetDailyEnergySection(energy: $energy)
            PetDailyMealCareSection(
                didFeed: $didFeed,
                foodText: $foodText,
                didCleanPoop: $didCleanPoop,
                poopStatus: $poopStatus,
                didAddWater: $didAddWater
            )
            PetDailyExerciseCareSection(
                didBath: $didBath
            )
            PetDailyNoteSection(note: $note)
        }
    }
}

// PetDailyMealCareSection 饮食排泄记录区
// 核心职责：
// - 收集喂食、排泄和补水打卡
// - 复用病历表单卡片和行分割视觉
private struct PetDailyMealCareSection: View {
    @Binding var didFeed: Bool
    @Binding var foodText: String
    @Binding var didCleanPoop: Bool
    @Binding var poopStatus: PetDailyRecordPoopStatus
    @Binding var didAddWater: Bool

    var body: some View {
        PetDailyChecklistSection(title: "饮食与排泄") {
            PetRecordFormCard {
                PetDailyCheckItem(
                    title: "完成喂食",
                    systemImage: "fork.knife",
                    isOn: $didFeed
                ) {
                    PetRecordFormTextRow(
                        title: "主食内容",
                        text: $foodText,
                        prompt: "例如 渴望六种鱼"
                    )
                }
                PetRecordFormDivider()
                PetDailyCheckItem(
                    title: "清理粪便",
                    systemImage: "trash.fill",
                    isOn: $didCleanPoop
                ) {
                    VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
                        Text("形态记录")
                            .font(MHBTheme.Typography.caption)
                            .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                        PetDailyChipGroup(
                            options: PetDailyRecordPoopStatus.allCases,
                            selection: $poopStatus,
                            title: \.title
                        )
                    }
                }
                PetRecordFormDivider()
                PetDailyCheckItem(
                    title: "补充水分",
                    systemImage: "drop.fill",
                    isOn: $didAddWater
                )
            }
        }
    }
}

// PetDailyExerciseCareSection 运动护理记录区
// 核心职责：
// - 收集清洁类日常动作
// - 维持与病历表单一致的卡片行布局
private struct PetDailyExerciseCareSection: View {
    @Binding var didBath: Bool

    var body: some View {
        PetDailyChecklistSection(title: "运动与护理") {
            PetRecordFormCard {
                PetDailyCheckItem(
                    title: "洗澡清洁",
                    systemImage: "shower.fill",
                    isOn: $didBath
                )
            }
        }
    }
}

// PetDailyHeaderSection 日常记录头部
// 核心职责：
// - 展示当前宠物上下文
// - 收集本次日常记录发生时间
private struct PetDailyHeaderSection: View {
    let petID: String?
    let petSex: PetRecordPetSex
    @Binding var occurredAt: Date

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
            PetRecordPetIdentityCard(
                petID: petID,
                petSex: petSex,
                description: "正在为它添加日常记录"
            )

            DatePicker(
                "时间",
                selection: $occurredAt,
                displayedComponents: [.date, .hourAndMinute]
            )
            .font(MHBTheme.Typography.callout)
            .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
        }
    }
}

// PetDailyEnergySection 日常精神状态区
// 核心职责：
// - 展示精神与活力选项
// - 使用轻量直铺布局表达精神状态选项
private struct PetDailyEnergySection: View {
    @Binding var energy: PetDailyRecordEnergy

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
            Text("精神与活力")
                .font(MHBTheme.Typography.section)
                .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
                .textCase(.uppercase)

            PetDailyChipGroup(
                options: PetDailyRecordEnergy.allCases,
                selection: $energy,
                title: \.title
            )
        }
    }
}

// PetDailyChecklistSection 日常打卡分组
// 核心职责：
// - 提供日常记录卡片上方的分组标题
// - 保持饮食、运动和备注区与病历表单卡片一致
private struct PetDailyChecklistSection<Content: View>: View {
    let title: LocalizedStringResource
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
            Text(title)
                .font(MHBTheme.Typography.section)
                .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
                .textCase(.uppercase)

            content()
        }
    }
}

// PetDailyNoteSection 日常备注区
// 核心职责：
// - 收集本次日常记录的补充描述
// - 以无背景输入区承载可选备注
private struct PetDailyNoteSection: View {
    @Binding var note: String

    var body: some View {
        PetDailyChecklistSection(title: "备注") {
            PetRecordFormCard {
                TextField("备注", text: $note, prompt: Text("添加备注（选填）"), axis: .vertical)
                    .lineLimit(4...7)
                    .font(MHBTheme.Typography.callout)
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                    .padding(.vertical, MHBTheme.Spacing.s2)
            }
        }
    }
}

// PetDailyChipGroup 日常记录单选标签组
// 核心职责：
// - 承载精神状态和粪便形态等单选项
// - 用明确选中态表达当前选择
private struct PetDailyChipGroup<Option: Identifiable & Equatable>: View {
    let options: [Option]
    @Binding var selection: Option
    let title: KeyPath<Option, String>

    private let columns = [
        GridItem(.adaptive(minimum: 94), spacing: MHBTheme.Spacing.s2, alignment: .leading)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: MHBTheme.Spacing.s2) {
            ForEach(options) { option in
                Button {
                    selection = option
                } label: {
                    Text(option[keyPath: title])
                        .font(MHBTheme.Typography.callout.weight(.semibold))
                        .foregroundStyle(selection == option ? MHBTheme.ColorToken.primary.color : MHBTheme.ColorToken.labelSecondary.color)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, MHBTheme.Spacing.s4)
                        .padding(.vertical, MHBTheme.Spacing.s2)
                        .background(
                            selection == option ? MHBTheme.ColorToken.primaryBackground.color : MHBTheme.ColorToken.primaryBackgroundSoft.color,
                            in: .rect(cornerRadius: MHBTheme.Radius.medium)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous)
                                .stroke(
                                    selection == option ? MHBTheme.ColorToken.primary.color.opacity(0.28) : MHBTheme.ColorToken.separator.color,
                                    lineWidth: 1
                                )
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// PetDailyCheckItem 日常记录打卡行
// 核心职责：
// - 展示一项日常打卡动作
// - 在选中后展开该动作的补充内容
private struct PetDailyCheckItem<Content: View>: View {
    let title: LocalizedStringResource
    let systemImage: String
    @Binding var isOn: Bool
    @ViewBuilder var content: () -> Content

    init(
        title: LocalizedStringResource,
        systemImage: String,
        isOn: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content = { EmptyView() }
    ) {
        self.title = title
        self.systemImage = systemImage
        self._isOn = isOn
        self.content = content
    }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.snappy(duration: 0.28)) {
                    isOn.toggle()
                }
            } label: {
                HStack(spacing: MHBTheme.Spacing.s3) {
                    Image(systemName: systemImage)
                        .font(.system(size: MHBTheme.IconSize.small, weight: .semibold))
                        .foregroundStyle(isOn ? MHBTheme.ColorToken.primary.color : MHBTheme.ColorToken.labelTertiary.color)
                        .frame(width: 22)
                    Text(title)
                        .font(MHBTheme.Typography.headline)
                        .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                    Spacer()
                    Image(systemName: isOn ? "checkmark.square.fill" : "square")
                        .font(.system(size: MHBTheme.IconSize.medium, weight: .semibold))
                        .foregroundStyle(isOn ? MHBTheme.ColorToken.primary.color : MHBTheme.ColorToken.labelTertiary.color)
                }
                .padding(.vertical, MHBTheme.Spacing.s4)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            if isOn {
                VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
                    content()
                }
                .padding(.leading, MHBTheme.Spacing.s8)
                .padding(.bottom, MHBTheme.Spacing.s4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}
