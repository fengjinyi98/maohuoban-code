import SwiftUI
import MaohuobanDesignSystem

// PetDailyRecordContent 日常记录页面内容
// 核心职责：
// - 组合宠物、时间、精神状态、饮食排泄、运动护理和备注输入
// - 通过 Binding 将日常打卡状态回传给提交层
struct PetDailyRecordContent: View {
    let petID: String?
    @Binding var occurredAt: Date
    @Binding var energy: PetDailyRecordEnergy
    @Binding var didFeed: Bool
    @Binding var foodText: String
    @Binding var didCleanPoop: Bool
    @Binding var poopStatus: PetDailyRecordPoopStatus
    @Binding var didAddWater: Bool
    @Binding var didWalk: Bool
    @Binding var didBath: Bool
    @Binding var note: String

    var body: some View {
        VStack(spacing: 0) {
            PetDailyHeaderSection(petID: petID, occurredAt: $occurredAt)
            PetDailyFlatSection(title: "精神与活力") {
                PetDailyChipGroup(
                    options: PetDailyRecordEnergy.allCases,
                    selection: $energy,
                    title: \.title
                )
            }
            PetDailyThickDivider()
            PetDailyFlatSection(title: "饮食与排泄") {
                PetDailyCheckItem(
                    title: "完成喂食",
                    systemImage: "fork.knife",
                    isOn: $didFeed
                ) {
                    PetHealthTextInputRow(
                        title: "主食内容",
                        systemImage: "takeoutbag.and.cup.and.straw.fill",
                        text: $foodText,
                        prompt: "例如 渴望六种鱼"
                    )
                }
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
                PetDailyCheckItem(
                    title: "补充水分",
                    systemImage: "drop.fill",
                    isOn: $didAddWater
                )
            }
            PetDailyThickDivider()
            PetDailyFlatSection(title: "运动与护理") {
                PetDailyCheckItem(
                    title: "户外遛弯",
                    systemImage: "figure.walk",
                    isOn: $didWalk
                )
                PetDailyCheckItem(
                    title: "洗澡清洁",
                    systemImage: "shower.fill",
                    isOn: $didBath
                )
            }
            PetDailyThickDivider()
            PetDailyFlatSection(title: "附加信息") {
                TextField("添加备注（选填）", text: $note, axis: .vertical)
                    .lineLimit(4...7)
                    .font(MHBTheme.Typography.body)
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                    .padding(.vertical, MHBTheme.Spacing.s4)
            }
        }
        .background(MHBTheme.ColorToken.cardSolid.color)
    }
}

// PetDailyHeaderSection 日常记录头部
// 核心职责：
// - 展示当前宠物上下文
// - 收集本次日常记录发生时间
private struct PetDailyHeaderSection: View {
    let petID: String?
    @Binding var occurredAt: Date

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s3) {
            HStack(spacing: MHBTheme.Spacing.s2) {
                Image(systemName: "pawprint.fill")
                    .font(.system(size: MHBTheme.IconSize.small, weight: .semibold))
                    .foregroundStyle(MHBTheme.ColorToken.primary.color)
                    .frame(width: 32, height: 32)
                    .background(MHBTheme.ColorToken.primaryBackground.color, in: Circle())
                Text(petID == nil ? "未选择宠物" : "当前宠物")
                    .font(MHBTheme.Typography.callout.weight(.semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
            }
            .padding(.leading, MHBTheme.Spacing.s2)
            .padding(.trailing, MHBTheme.Spacing.s3)
            .padding(.vertical, MHBTheme.Spacing.s1)
            .background(MHBTheme.ColorToken.primaryBackgroundSoft.color, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(MHBTheme.ColorToken.separator.color, lineWidth: 1)
            }

            Spacer(minLength: MHBTheme.Spacing.s2)

            DatePicker(
                "发生时间",
                selection: $occurredAt,
                displayedComponents: [.date, .hourAndMinute]
            )
            .labelsHidden()
            .font(MHBTheme.Typography.callout.weight(.semibold))
        }
        .padding(.horizontal, MHBTheme.Spacing.s4)
        .padding(.vertical, MHBTheme.Spacing.s3)
    }
}

// PetDailyFlatSection 日常记录平铺分组
// 核心职责：
// - 提供日常记录页面的无卡片分区
// - 统一标题、左右留白和内容间距
private struct PetDailyFlatSection<Content: View>: View {
    let title: LocalizedStringResource
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
            Text(title)
                .font(MHBTheme.Typography.section)
                .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
                .padding(.top, MHBTheme.Spacing.s5)

            content()
                .padding(.bottom, MHBTheme.Spacing.s5)
        }
        .padding(.horizontal, MHBTheme.Spacing.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
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

            PetHealthDivider()
        }
    }
}

// PetDailyThickDivider 日常记录分区带
// 核心职责：
// - 使用宽分割带表达日常表单区块边界
// - 避免额外卡片嵌套造成页面拥挤
private struct PetDailyThickDivider: View {
    var body: some View {
        Rectangle()
            .fill(MHBTheme.ColorToken.background.color)
            .frame(height: MHBTheme.Spacing.s2)
    }
}

// PetDailyRecordBottomBar 日常记录底部操作栏
// 核心职责：
// - 以一行双按钮承载保存与发布前记录动作
// - 复用发布页底部操作栏的胶囊按钮和玻璃底栏形态
struct PetDailyRecordBottomBar: View {
    let isSubmitting: Bool
    let onRecordAndPublish: () -> Void
    let onSave: () -> Void

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s3) {
            Button(action: onRecordAndPublish) {
                Text("记录并去发布动态")
                    .font(MHBTheme.Typography.headline)
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(MHBTheme.ColorToken.cardSolid.color)
                    .clipShape(Capsule())
                    .overlay {
                        Capsule()
                            .stroke(MHBTheme.ColorToken.separator.color, lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .disabled(isSubmitting)
            .accessibilityIdentifier("pet.dailyRecord.action.recordAndPublish")

            Button(action: onSave) {
                Text(isSubmitting ? "保存中" : "保存")
                    .font(MHBTheme.Typography.headline)
                    .foregroundStyle(.white)
                    .frame(width: 96)
                    .frame(height: 40)
                    .background(
                        isSubmitting
                            ? MHBTheme.ColorToken.primary.color.opacity(0.5)
                            : MHBTheme.ColorToken.primary.color
                    )
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(isSubmitting)
            .accessibilityIdentifier("pet.dailyRecord.action.save")
        }
    }
}
