import SwiftUI
import MaohuobanDesignSystem

// PetMedicalRecordFormSheet 病历记录表单弹层
// 核心职责：
// - 收集新增病历或追加病历的前端 mock 表单输入
// - 使用底部 CTA 触发表单保存回调
struct PetMedicalRecordFormSheet: View {
    @Environment(\.dismiss) private var dismiss

    let mode: PetMedicalRecordFormMode
    let onSave: (PetMedicalRecordDraft) -> Void

    @State private var draft = PetMedicalRecordDraft()

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let bottomInset = proxy.safeAreaInsets.bottom

                ZStack(alignment: .topLeading) {
                    MHBTheme.ColorToken.background.color
                        .ignoresSafeArea()

                    MHBScreenScrollView {
                        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s5) {
                            PetMedicalRecordDateSection(date: $draft.occurredAt)

                            if mode == .create {
                                PetMedicalRecordVisitSection(draft: $draft)
                            }

                            PetMedicalRecordTreatmentSection(draft: $draft)
                            PetMedicalRecordNoteSection(note: $draft.note)
                        }
                        .padding(.horizontal, MHBTheme.Spacing.s5)
                        .padding(.top, MHBTheme.Spacing.s8)
                        .padding(.bottom, MHBTheme.Spacing.s8 + MHBTheme.Spacing.s8 + MHBTheme.Spacing.s6)
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)

                    MHBBottomFloatingActionCTA(
                        title: mode.saveTitle,
                        systemImage: "checkmark",
                        bottomInset: bottomInset,
                        action: save
                    )
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottom)
                    .disabled(!canSave)
                    .opacity(canSave ? 1 : 0.46)
                    .zIndex(2)
                }
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            }
            .ignoresSafeArea(.container, edges: .bottom)
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(24)
    }

    private var canSave: Bool {
        switch mode {
        case .create:
            draft.canCreateRecord
        case .append:
            draft.canAppendUpdate
        }
    }

    private func save() {
        guard canSave else { return }
        onSave(draft)
        dismiss()
    }
}
