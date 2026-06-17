import SwiftUI
import MaohuobanDesignSystem

// PetProfileWeightEditorSheet 宠物体重编辑弹层
// 核心职责：
// - 收集宠物体重数值
// - 统一体重输入的格式约束和保存状态
struct PetProfileWeightEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var weight: String
    let onWillDismiss: () -> Void
    let onSave: () -> Void

    private let weightLimit = 6

    private var trimmedWeight: String {
        weight.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isWeightValid: Bool {
        guard !trimmedWeight.isEmpty else { return false }
        return Double(trimmedWeight) != nil
    }

    private var saveColor: Color {
        MHBTheme.ColorToken.primary.color.opacity(isWeightValid ? 1 : 0.35)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
                HStack(alignment: .center, spacing: MHBTheme.Spacing.s3) {
                    TextField("请输入体重", text: $weight)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                        .keyboardType(.decimalPad)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Text("kg")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                }
                .padding(.horizontal, MHBTheme.Spacing.s4)
                .frame(minHeight: 56)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))

                Text("体重用于健康趋势记录，可保留一位小数。")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)

                Spacer()
            }
            .padding(.horizontal, MHBTheme.Spacing.s4)
            .padding(.top, MHBTheme.Spacing.s4)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("编辑体重")
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
                    .disabled(!isWeightValid)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .background(MHBPresentationDismissObserver(onWillDismiss: onWillDismiss))
        .onChange(of: weight) { _, newValue in
            let normalizedWeight = normalizedWeight(from: newValue)
            if normalizedWeight != newValue {
                weight = normalizedWeight
            }
        }
    }

    private func saveIfNeeded() {
        guard isWeightValid else { return }
        weight = trimmedWeight
        onWillDismiss()
        onSave()
        dismiss()
    }

    private func normalizedWeight(from value: String) -> String {
        var hasDot = false
        var result = ""

        for character in value {
            if character == ".", !hasDot {
                hasDot = true
                result.append(character)
            } else if character.unicodeScalars.count == 1,
                      let scalar = character.unicodeScalars.first,
                      (48...57).contains(scalar.value) {
                result.append(character)
            }

            if result.count >= weightLimit {
                break
            }
        }

        return result
    }
}
