import SwiftUI
import MaohuobanDesignSystem
import UIKit

// PetProfileNameEditorSheet 宠物昵称编辑弹层
// 核心职责：
// - 承载宠物名字的临时编辑和字数提示
// - 统一保存校验、禁用态和关闭行为
struct PetProfileNameEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var name: String
    @State private var isInputComposing = false
    let policyText: String?
    let onWillDismiss: () -> Void
    let onSave: () -> Void

    private let nameInputLimit = MHBStableTextInputLimit(maxCount: 6, countingRule: .nonWhitespace)
    private let invalidCharacterSet = CharacterSet(charactersIn: "@<>/")

    private var normalizedName: String {
        name.filter { !$0.isWhitespace }
    }

    private var isNameValid: Bool {
        !normalizedName.isEmpty
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
                        "请输入宠物名字",
                        text: $name,
                        isComposing: $isInputComposing,
                        onSubmit: saveIfNeeded
                    )
                    .frame(maxWidth: .infinity, minHeight: 24, maxHeight: 24, alignment: .leading)

                    Text("\(nameLimitState.count)/\(nameLimitState.maxCount)")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(nameLimitState.isExceeded ? MHBTheme.ColorToken.danger.color : MHBTheme.ColorToken.labelTertiary.color)
                        .monospacedDigit()
                }
                .padding(.horizontal, MHBTheme.Spacing.s4)
                .frame(minHeight: 56)
                .mhbStableTextInputContainer(isError: nameLimitState.isExceeded)

                VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
                    Text("最多输入 \(nameLimitState.maxCount) 个字符，空格不计入字数。")
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
            .navigationTitle("编辑名字")
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
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .background(MHBPresentationDismissObserver(onWillDismiss: onWillDismiss))
        .accessibilityIdentifier("pet.profileEdit.nameEditor.sheet")
    }

    private func saveIfNeeded() {
        guard isSaveEnabled else { return }
        name = normalizedName
        onWillDismiss()
        onSave()
        dismiss()
    }
}
