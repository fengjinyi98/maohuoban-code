import SwiftUI
import MaohuobanDesignSystem
import UIKit

// PetProfileChipEditorSheet 宠物芯片号编辑弹层
// 核心职责：
// - 校验 ISO 11784 / ISO 11785 FDX-B 的 15 位纯数字编码
// - 在保存前要求用户二次确认不可修改的芯片号
struct PetProfileChipEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var chipNumber: String
    let existingChipNumber: String
    let onWillDismiss: () -> Void
    let onSave: () -> Void

    @State private var isConfirmingSave = false

    private let chipNumberLength = 15

    private var isExistingChipNumberLocked: Bool {
        !existingChipNumber.isEmpty
    }

    private var trimmedChipNumber: String {
        chipNumber.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isChipNumberValid: Bool {
        trimmedChipNumber.count == chipNumberLength
            && normalizedChipNumber(from: trimmedChipNumber) == trimmedChipNumber
    }

    private var saveColor: Color {
        MHBTheme.ColorToken.primary.color.opacity(isChipNumberValid ? 1 : 0.35)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
                if isExistingChipNumberLocked {
                    lockedChipNumberContent
                } else {
                    editableChipNumberContent
                }

                Text("宠物芯片号采用 ISO 11784 / ISO 11785 FDX-B 标准，为 15 位纯数字编码。芯片号添加后不可自行修改，如需变更需通过申诉渠道处理。")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()
            }
            .padding(.horizontal, MHBTheme.Spacing.s4)
            .padding(.top, MHBTheme.Spacing.s4)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(isExistingChipNumberLocked ? "芯片号" : "添加芯片号")
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

                if !isExistingChipNumberLocked {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("保存") {
                            isConfirmingSave = true
                        }
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(saveColor)
                        .disabled(!isChipNumberValid)
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .background(MHBPresentationDismissObserver(onWillDismiss: onWillDismiss))
        .onChange(of: chipNumber) { _, newValue in
            let normalizedDigits = normalizedChipNumber(from: newValue)

            if normalizedDigits != newValue {
                chipNumber = normalizedDigits
            }
        }
        .alert(
            "确认芯片号",
            isPresented: $isConfirmingSave
        ) {
            Button("返回检查", role: .cancel) {}

            Button("确认添加") {
                saveConfirmedChipNumber()
            }
        } message: {
            Text("请确认芯片号 \(trimmedChipNumber) 准确无误。添加后不可自行修改，如需变更需通过申诉渠道处理。")
        }
        .accessibilityIdentifier("pet.profileEdit.chipEditor.sheet")
    }

    private var editableChipNumberContent: some View {
        HStack(alignment: .center, spacing: MHBTheme.Spacing.s3) {
            TextField("请输入 15 位芯片号", text: $chipNumber)
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .keyboardType(.numberPad)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            Text("\(chipNumber.count)/\(chipNumberLength)")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
                .monospacedDigit()
        }
        .padding(.horizontal, MHBTheme.Spacing.s4)
        .frame(minHeight: 56)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
    }

    private var lockedChipNumberContent: some View {
        HStack(alignment: .center, spacing: MHBTheme.Spacing.s3) {
            Text(existingChipNumber)
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .monospacedDigit()

            Spacer(minLength: MHBTheme.Spacing.s3)

            Text("已添加")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
        }
        .padding(.horizontal, MHBTheme.Spacing.s4)
        .frame(minHeight: 56)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
    }

    private func saveConfirmedChipNumber() {
        guard isChipNumberValid else { return }
        chipNumber = trimmedChipNumber
        onWillDismiss()
        onSave()
        dismiss()
    }

    private func normalizedChipNumber(from value: String) -> String {
        let digits = value.compactMap { character -> Character? in
            guard character.unicodeScalars.count == 1,
                  let scalar = character.unicodeScalars.first,
                  (48...57).contains(scalar.value) else {
                return nil
            }

            return character
        }

        return String(digits.prefix(chipNumberLength))
    }
}
