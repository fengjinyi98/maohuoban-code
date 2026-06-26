import SwiftUI
import MaohuobanDesignSystem

// Internal: extracted from PetAbnormalRecordDetailTimelineSections

// PetAbnormalRecordActionSheet 异常事件动作表单
// 核心职责：
// - 承载追加观察和标记恢复的表单输入
// - 通过 PetAbnormalDetailStore 提交真实事件
struct PetAbnormalRecordActionSheet: View {
    @Environment(\.dismiss) private var dismiss

    let action: PetAbnormalRecordDetailAction
    let store: PetAbnormalDetailStore
    @Binding var observationNote: String
    @Binding var recoveryNote: String
    let petID: String?
    let currentUserID: String?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s5) {
                HStack(spacing: MHBTheme.Spacing.s4) {
                    Image(systemName: action.systemImage)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(action.tint)
                        .frame(width: 56, height: 56)
                        .background(action.tint.opacity(0.10), in: Circle())

                    VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
                        Text(action.title)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                        Text(action.subtitle)
                            .font(MHBTheme.Typography.caption)
                            .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    }
                }

                PetAbnormalActionFormField(
                    action: action,
                    observationNote: $observationNote,
                    recoveryNote: $recoveryNote
                )

                if let message = actionMessage {
                    Text(message)
                        .font(MHBTheme.Typography.caption)
                        .foregroundStyle(
                            store.actionPhase == .failed(message) ? MHBTheme.ColorToken.danger.color : MHBTheme.ColorToken.success.color
                        )
                }

                Spacer()

                Button {
                    Task { await submit() }
                } label: {
                    HStack {
                        if store.isSubmitting {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(store.isSubmitting ? "提交中" : submitTitle)
                    }
                    .font(MHBTheme.Typography.callout.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(submitButtonColor, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(store.isSubmitting || petID == nil)
            }
            .padding(MHBTheme.Spacing.s5)
            .background(MHBTheme.ColorToken.background.color)
            .navigationTitle(action.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                        .font(MHBTheme.Typography.callout)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(store.isSubmitting)
    }

    private var submitTitle: String {
        switch action {
        case .addObservation: "追加观察"
        case .linkClinicVisit: "关联就诊"
        case .markRecovered: "标记恢复"
        }
    }

    private var submitButtonColor: Color {
        if store.isSubmitting {
            MHBTheme.ColorToken.labelTertiary.color
        }
        return action.tint
    }

    private var actionMessage: String? {
        switch store.actionPhase {
        case .succeeded(let msg): msg
        case .failed(let msg): msg
        default: nil
        }
    }

    private func submit() async {
        guard let petID else { return }
        switch action {
        case .addObservation:
            await store.addObservation(
                petID: petID,
                note: observationNote,
                currentUserID: currentUserID,
                lifeStatus: nil
            )
        case .markRecovered:
            await store.markRecovered(
                petID: petID,
                note: recoveryNote,
                currentUserID: currentUserID,
                lifeStatus: nil
            )
        case .linkClinicVisit:
            break
        }
    }
}

// PetAbnormalActionFormField 动作表单输入
// 核心职责：
// - 根据动作类型展示不同的表单字段
struct PetAbnormalActionFormField: View {
    let action: PetAbnormalRecordDetailAction
    @Binding var observationNote: String
    @Binding var recoveryNote: String

    var body: some View {
        switch action {
        case .addObservation:
            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
                Text("观察内容")
                    .font(MHBTheme.Typography.callout.weight(.semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                TextEditor(text: $observationNote)
                    .font(MHBTheme.Typography.callout)
                    .frame(minHeight: 80)
                    .padding(MHBTheme.Spacing.s2)
                    .background(MHBTheme.ColorToken.cardSolid.color)
                    .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous)
                            .stroke(MHBTheme.ColorToken.separatorSoft.color, lineWidth: 1)
                    )
            }
        case .markRecovered:
            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
                Text("恢复表现")
                    .font(MHBTheme.Typography.callout.weight(.semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                TextEditor(text: $recoveryNote)
                    .font(MHBTheme.Typography.callout)
                    .frame(minHeight: 80)
                    .padding(MHBTheme.Spacing.s2)
                    .background(MHBTheme.ColorToken.cardSolid.color)
                    .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous)
                            .stroke(MHBTheme.ColorToken.separatorSoft.color, lineWidth: 1)
                    )
            }
        case .linkClinicVisit:
            Text("关联就诊功能将在后续版本接入")
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
        }
    }
}

// PetAbnormalRecordRelatedRecordSheet 异常事件关联记录预览
// 核心职责：
// - 在快速 UI 阶段展示关联记录点击后的目标形态
// - 后续接入真实详情页后替换为对应记录路由
struct PetAbnormalRecordRelatedRecordSheet: View {
    @Environment(\.dismiss) private var dismiss

    let record: PetAbnormalRecordDetailPresentation.RelatedRecord

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s5) {
                Image(systemName: record.kind.systemImage)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(record.kind.tint)
                    .frame(width: 64, height: 64)
                    .background(record.kind.tint.opacity(0.10), in: Circle())

                VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
                    Text(record.title)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

                    Text(record.timeText)
                        .font(MHBTheme.Typography.caption)
                        .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)

                    Text(record.subtitle)
                        .font(MHBTheme.Typography.callout)
                        .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Button("关闭") {
                    dismiss()
                }
                .font(MHBTheme.Typography.callout.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(MHBTheme.ColorToken.primary.color, in: Capsule())
                .buttonStyle(.plain)
            }
            .padding(MHBTheme.Spacing.s5)
            .background(MHBTheme.ColorToken.background.color)
            .navigationTitle(record.kind.title)
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}
