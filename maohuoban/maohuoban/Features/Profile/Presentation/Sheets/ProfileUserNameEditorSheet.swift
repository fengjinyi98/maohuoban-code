import SwiftUI
import MaohuobanDesignSystem

// ProfileUserNameEditorSheet 用户昵称编辑弹层
// 核心职责：
// - 承载用户昵称的临时编辑和字数提示
// - 统一保存校验、禁用态和关闭行为
struct ProfileUserNameEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var name: String
    @State private var isInputComposing = false
    let policyText: String?
    let onWillDismiss: () -> Void
    let onSave: () -> Void

    private let nameInputLimit = MHBStableTextInputLimit(maxCount: 24)
    private let invalidCharacterSet = CharacterSet(charactersIn: "@<>/")

    private var normalizedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isNameValid: Bool {
        normalizedName.count >= 2
            && !nameLimitState.isExceeded
            && normalizedName.rangeOfCharacter(from: invalidCharacterSet) == nil
    }

    private var nameLimitState: MHBStableTextInputLimitState {
        nameInputLimit.state(for: name)
    }

    private var isSaveEnabled: Bool {
        isNameValid && !isInputComposing
    }

    private var saveColor: Color {
        MHBTheme.ColorToken.primary.color.opacity(isSaveEnabled ? 1 : 0.35)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
                HStack(alignment: .center, spacing: MHBTheme.Spacing.s3) {
                    MHBStableTextField(
                        "请输入昵称",
                        text: $name,
                        isComposing: $isInputComposing,
                        onSubmit: saveIfNeeded
                    )
                    .frame(maxWidth: .infinity, minHeight: 24, maxHeight: 24, alignment: .leading)
                    .accessibilityIdentifier("profile.userEdit.nameEditor.input")

                    Text("\(nameLimitState.count)/\(nameLimitState.maxCount)")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(nameLimitState.isExceeded ? MHBTheme.ColorToken.danger.color : MHBTheme.ColorToken.labelTertiary.color)
                        .monospacedDigit()
                }
                .padding(.horizontal, MHBTheme.Spacing.s4)
                .frame(minHeight: 56)
                .mhbStableTextInputContainer(isError: nameLimitState.isExceeded)

                VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
                    Text("请设置 2-24 个字符，不包含 @、<、>、/。")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(nameLimitState.isExceeded ? MHBTheme.ColorToken.danger.color : MHBTheme.ColorToken.labelTertiary.color)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)

                    if let policyText {
                        Text(policyText)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, MHBTheme.Spacing.s4)
            .padding(.top, MHBTheme.Spacing.s4)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("编辑昵称")
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
                    .disabled(!isSaveEnabled)
                    .accessibilityIdentifier("profile.userEdit.nameEditor.saveButton")
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .background(MHBPresentationDismissObserver(onWillDismiss: onWillDismiss))
        .accessibilityIdentifier("profile.userEdit.nameEditor.sheet")
    }

    private func saveIfNeeded() {
        guard isSaveEnabled else { return }
        name = normalizedName
        onWillDismiss()
        onSave()
        dismiss()
    }
}
