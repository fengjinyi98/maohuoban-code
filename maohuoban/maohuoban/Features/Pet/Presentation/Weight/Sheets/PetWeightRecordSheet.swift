import SwiftUI
import MaohuobanDesignSystem

// PetWeightRecordSheet 体重记录弹层
// 核心职责：
// - 通过原生 sheet 收集体重、记录时间和备注
// - 将新增或编辑草稿交给父级 Store 统一提交
struct PetWeightRecordSheet: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isWeightFocused: Bool

    let petName: String
    let mode: PetWeightRecordSheetMode
    let onSave: (PetWeightRecordDraft) async -> Bool

    @State private var weightText: String
    @State private var recordedAt: Date
    @State private var noteText: String
    @State private var isSaving = false

    private let weightLimit = 6

    init(
        petName: String,
        initialWeightText: String,
        mode: PetWeightRecordSheetMode = .create,
        onSave: @escaping (PetWeightRecordDraft) async -> Bool
    ) {
        self.petName = petName
        self.mode = mode
        self.onSave = onSave
        self._weightText = State(initialValue: mode.initialWeightText ?? initialWeightText)
        self._recordedAt = State(initialValue: mode.initialDate ?? Date())
        self._noteText = State(initialValue: mode.initialNote)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                PetWeightRecordInputStage(
                    weightText: $weightText,
                    isFocused: $isWeightFocused
                )

                VStack(spacing: 0) {
                    PetWeightRecordDateRow(recordedAt: $recordedAt)
                    PetWeightRecordNoteSection(noteText: $noteText)
                }

                Spacer(minLength: MHBTheme.Spacing.s5)

                PetWeightRecordSaveButton(
                    title: mode.saveButtonTitle,
                    isEnabled: isWeightValid && !isSaving,
                    action: {
                        Task {
                            await saveRecord()
                        }
                    }
                )
                .padding(.horizontal, MHBTheme.Spacing.s5)
                .padding(.bottom, MHBTheme.Spacing.s5)
            }
            .background(MHBTheme.ColorToken.background.color)
            .navigationTitle(mode.navigationTitle(petName: petName))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    PetWeightRecordCloseButton {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.height(560), .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(24)
        .onAppear {
            isWeightFocused = true
        }
        .onChange(of: weightText) { _, newValue in
            let normalizedValue = normalizedWeight(from: newValue)
            if normalizedValue != newValue {
                weightText = normalizedValue
            }
        }
        .accessibilityIdentifier("pet.weightRecord.sheet")
    }

    private var trimmedWeight: String {
        weightText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedNote: String {
        noteText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isWeightValid: Bool {
        guard !trimmedWeight.isEmpty else { return false }
        return Double(trimmedWeight) != nil
    }

    private func saveRecord() async {
        guard isWeightValid, !isSaving, let weight = Double(trimmedWeight) else { return }
        isSaving = true
        let draft = PetWeightRecordDraft(
            weightGrams: Int((weight * 1000).rounded()),
            note: trimmedNote.isEmpty ? nil : trimmedNote,
            occurredAt: PetWriteFormatters.occurredAtString(from: recordedAt)
        )
        let didSave = await onSave(draft)
        isSaving = false
        if didSave {
            dismiss()
        }
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
