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
    let onWillDismiss: () -> Void
    let onSave: () -> Void

    private let nameLimit = 24
    private let invalidCharacterSet = CharacterSet(charactersIn: "@<>/")

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isNameValid: Bool {
        trimmedName.count >= 2
            && trimmedName.count <= nameLimit
            && trimmedName.rangeOfCharacter(from: invalidCharacterSet) == nil
    }

    private var saveColor: Color {
        MHBTheme.ColorToken.primary.color.opacity(isNameValid ? 1 : 0.35)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
                HStack(alignment: .center, spacing: MHBTheme.Spacing.s3) {
                    TextField("请输入宠物名字", text: $name)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .onSubmit {
                            saveIfNeeded()
                        }

                    Text("\(name.count)/\(nameLimit)")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
                        .monospacedDigit()
                }
                .padding(.horizontal, MHBTheme.Spacing.s4)
                .frame(minHeight: 56)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))

                // TODO: 昵称修改额度说明由后端返回，包含截止日期和剩余修改次数。
                Text("请设置 2-24 个字符，不包括 @<>/等无效字符。30 天内可修改 4 次昵称，07.17 前还可修改 4 次。")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

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
                    .disabled(!isNameValid)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .background(MHBPresentationDismissObserver(onWillDismiss: onWillDismiss))
        .onChange(of: name) { _, newValue in
            if newValue.count > nameLimit {
                name = String(newValue.prefix(nameLimit))
            }
        }
        .accessibilityIdentifier("pet.profileEdit.nameEditor.sheet")
    }

    private func saveIfNeeded() {
        guard isNameValid else { return }
        name = trimmedName
        onWillDismiss()
        onSave()
        dismiss()
    }
}
