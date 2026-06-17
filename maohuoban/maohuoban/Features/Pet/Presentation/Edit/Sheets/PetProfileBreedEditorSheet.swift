import SwiftUI
import MaohuobanDesignSystem

// PetProfileBreedEditorSheet 宠物品种编辑弹层
// 核心职责：
// - 承载宠物品种的单行输入
// - 统一品种保存前的空白规范化
struct PetProfileBreedEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var breed: String
    @State private var isInputComposing = false
    let onWillDismiss: () -> Void
    let onSave: (PetProfileBreedEditSubmission) -> Void

    private var saveColor: Color {
        MHBTheme.ColorToken.primary.color.opacity(isInputComposing ? 0.35 : 1)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
                MHBStableTextField(
                    "请输入宠物品种",
                    text: $breed,
                    isComposing: $isInputComposing,
                    onSubmit: saveIfNeeded
                )
                .padding(.horizontal, MHBTheme.Spacing.s4)
                .frame(height: 56)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))

                Spacer()
            }
            .padding(.horizontal, MHBTheme.Spacing.s4)
            .padding(.top, MHBTheme.Spacing.s4)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("编辑品种")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        onWillDismiss()
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                    .accessibilityLabel("关闭")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        saveIfNeeded()
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(saveColor)
                    .disabled(isInputComposing)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .background(MHBPresentationDismissObserver(onWillDismiss: onWillDismiss))
        .accessibilityIdentifier("pet.profileEdit.breedEditor.sheet")
    }

    private func saveIfNeeded() {
        guard !isInputComposing else { return }
        let submission = PetProfileBreedEditSubmission(rawValue: breed)
        breed = submission.value
        onSave(submission)
        onWillDismiss()
        dismiss()
    }
}
