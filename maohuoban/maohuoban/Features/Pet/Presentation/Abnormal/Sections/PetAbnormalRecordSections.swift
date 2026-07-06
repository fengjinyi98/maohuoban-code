import SwiftUI
import MaohuobanDesignSystem

// PetAbnormalRecordSummaryCard 异常记录引导卡
// 核心职责：
// - 明确异常记录的采集目标
// - 提醒用户补充后续判断需要的关键线索
struct PetAbnormalRecordSummaryCard: View {
    var body: some View {
        HStack(alignment: .top, spacing: MHBTheme.Spacing.s3) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.danger.color)
                .frame(width: 44, height: 44)
                .background(MHBTheme.ColorToken.danger.color.opacity(0.10), in: RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))

            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
                Text("记录异常")
                    .font(MHBTheme.Typography.title.weight(.bold))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

                Text("先记录症状和表现，后续可以在记录详情里继续追踪恢复、就诊或补充照片。")
                    .font(MHBTheme.Typography.callout)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(MHBTheme.Spacing.s4)
        .background(MHBTheme.ColorToken.cardSolid.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.extraLarge, style: .continuous))
        .shadow(color: MHBTheme.ColorToken.labelPrimary.color.opacity(0.03), radius: 16, y: 4)
    }
}

// PetAbnormalSymptomSection 异常症状区
// 核心职责：
// - 支持一级异常症状多选
// - 根据已选症状展开具体表现标签
struct PetAbnormalSymptomSection: View {
    @Binding var selectedSymptoms: Set<PetAbnormalSymptom>
    @Binding var selectedDetails: Set<String>

    var body: some View {
        PetAbnormalFormSection(title: "哪里异常") {
            PetAbnormalChoiceGrid {
                ForEach(PetAbnormalSymptom.allCases) { symptom in
                    PetAbnormalSelectableChip(
                        title: symptom.title,
                        systemImage: symptom.systemImage,
                        isSelected: selectedSymptoms.contains(symptom),
                        action: {
                            toggle(symptom)
                        }
                    )
                }
            }

            if selectedSymptoms.isEmpty == false {
                VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
                    Text("具体表现")
                        .font(MHBTheme.Typography.caption.weight(.semibold))
                        .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)

                    PetAbnormalChoiceGrid {
                        ForEach(detailOptions, id: \.self) { detail in
                            PetAbnormalTextChip(
                                title: detail,
                                isSelected: selectedDetails.contains(detail),
                                action: {
                                    if selectedDetails.contains(detail) {
                                        selectedDetails.remove(detail)
                                    } else {
                                        selectedDetails.insert(detail)
                                    }
                                }
                            )
                        }
                    }
                }
                .padding(.top, MHBTheme.Spacing.s2)
            }
        }
    }

    private var detailOptions: [String] {
        PetAbnormalSymptom.allCases
            .filter { selectedSymptoms.contains($0) }
            .flatMap(\.detailOptions)
    }

    private func toggle(_ symptom: PetAbnormalSymptom) {
        if selectedSymptoms.contains(symptom) {
            selectedSymptoms.remove(symptom)
            let remainingDetails = Set(detailOptions)
            selectedDetails = selectedDetails.intersection(remainingDetails)
        } else {
            selectedSymptoms.insert(symptom)
        }
    }
}

// PetAbnormalSeveritySection 异常程度区
// 核心职责：
// - 展示异常程度单选
// - 只让用户选择记录程度，不追加决断型说明
struct PetAbnormalSeveritySection: View {
    @Binding var severity: PetAbnormalSeverity

    var body: some View {
        PetAbnormalFormSection(title: "程度") {
            VStack(spacing: MHBTheme.Spacing.s2) {
                ForEach(PetAbnormalSeverity.allCases) { option in
                    Button {
                        severity = option
                    } label: {
                        HStack(alignment: .top, spacing: MHBTheme.Spacing.s3) {
                            Image(systemName: severity == option ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 18, weight: .semibold))

                            Text(option.title)
                                .font(MHBTheme.Typography.callout.weight(.semibold))

                            Spacer(minLength: MHBTheme.Spacing.s2)
                        }
                        .foregroundStyle(severity == option ? MHBTheme.ColorToken.primary.color : MHBTheme.ColorToken.labelPrimary.color)
                        .padding(MHBTheme.Spacing.s4)
                        .background(severity == option ? MHBTheme.ColorToken.primaryBackgroundSoft.color : MHBTheme.ColorToken.cardSolid.color)
                        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous)
                                .stroke(severity == option ? MHBTheme.ColorToken.primary.color : MHBTheme.ColorToken.separator.color, lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// PetAbnormalDateSection 异常发生时间区
// 核心职责：
// - 收集异常发生或被发现的时间
// - 保持原生 DatePicker 交互
struct PetAbnormalDateSection: View {
    @Binding var occurredAt: Date

    var body: some View {
        PetAbnormalFormSection(title: "发生时间") {
            DatePicker(
                "发生时间",
                selection: $occurredAt,
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

// PetAbnormalNoteSection 异常备注区
// 核心职责：
// - 收集持续时间、诱因和状态变化等补充描述
// - 保持多行输入区域稳定
struct PetAbnormalNoteSection: View {
    @Binding var note: String

    var body: some View {
        PetAbnormalFormSection(title: "备注") {
            TextField("备注", text: $note, prompt: Text("例如 持续多久、是否吃了新东西、精神是否变化"), axis: .vertical)
                .lineLimit(4...7)
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .padding(MHBTheme.Spacing.s3)
                .background(MHBTheme.ColorToken.cardSolid.color)
                .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous)
                        .stroke(MHBTheme.ColorToken.separator.color, lineWidth: 1)
                }
        }
    }
}

// PetAbnormalPhotoSection 异常照片区
// 核心职责：
// - 为异常记录提供可选照片入口
// - 复用事件附件网格展示即时上传结果
struct PetAbnormalPhotoSection: View {
    let attachments: [PetEventAttachmentDraft]
    let canAddMore: Bool
    let onAdd: () -> Void
    let onRemove: (UUID) -> Void
    let onRetry: (UUID) -> Void

    var body: some View {
        PetAbnormalFormSection(title: "照片（可选）") {
            PetEventAttachmentInputGrid(
                attachments: attachments,
                canAddMore: canAddMore,
                onAdd: onAdd,
                onRemove: onRemove,
                onRetry: onRetry
            )
        }
    }
}

// PetAbnormalFormSection 异常记录表单分组
// 核心职责：
// - 统一异常记录页的分组标题和内容间距
// - 保持表单扫描结构清晰
private struct PetAbnormalFormSection<Content: View>: View {
    let title: LocalizedStringResource
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
            Text(title)
                .font(MHBTheme.Typography.section)
                .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
                .textCase(.uppercase)

            content()
        }
    }
}

// PetAbnormalChoiceGrid 异常记录选项网格
// 核心职责：
// - 统一异常症状和具体表现的网格布局
// - 让选项尺寸在不同内容下保持稳定
private struct PetAbnormalChoiceGrid<Content: View>: View {
    @ViewBuilder let content: () -> Content

    private let columns = [
        GridItem(.adaptive(minimum: 92), spacing: MHBTheme.Spacing.s2, alignment: .leading)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: MHBTheme.Spacing.s2) {
            content()
        }
    }
}

// PetAbnormalSelectableChip 异常症状选择标签
// 核心职责：
// - 展示带 SF Symbol 的一级症状选项
// - 提供清晰选中态和稳定命中区域
private struct PetAbnormalSelectableChip: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(MHBTheme.Typography.callout.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .foregroundStyle(isSelected ? MHBTheme.ColorToken.primary.color : MHBTheme.ColorToken.labelSecondary.color)
                .frame(maxWidth: .infinity, minHeight: 44)
                .padding(.horizontal, MHBTheme.Spacing.s3)
                .background(isSelected ? MHBTheme.ColorToken.primaryBackgroundSoft.color : MHBTheme.ColorToken.cardSolid.color)
                .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous)
                        .stroke(isSelected ? MHBTheme.ColorToken.primary.color : MHBTheme.ColorToken.separator.color, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }
}

// PetAbnormalTextChip 异常具体表现标签
// 核心职责：
// - 展示不带图标的具体表现选项
// - 支持多选和清晰选中态
private struct PetAbnormalTextChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(MHBTheme.Typography.callout.weight(.semibold))
                .foregroundStyle(isSelected ? MHBTheme.ColorToken.primary.color : MHBTheme.ColorToken.labelSecondary.color)
                .frame(maxWidth: .infinity, minHeight: 38)
                .padding(.horizontal, MHBTheme.Spacing.s3)
                .background(isSelected ? MHBTheme.ColorToken.primaryBackgroundSoft.color : MHBTheme.ColorToken.cardSolid.color)
                .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous)
                        .stroke(isSelected ? MHBTheme.ColorToken.primary.color : MHBTheme.ColorToken.separator.color, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }
}
