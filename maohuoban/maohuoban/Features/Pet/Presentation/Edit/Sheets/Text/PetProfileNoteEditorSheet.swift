import SwiftUI
import MaohuobanDesignSystem

// PetProfileNoteEditorSheet 宠物备注编辑弹层
// 核心职责：
// - 承载宠物备注的多行输入
// - 统一备注字数限制和保存行为
struct PetProfileNoteEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var note: String
    let onWillDismiss: () -> Void
    let onSave: () -> Void

    @FocusState private var isFocused: Bool

    private let noteLimit = 160

    private var saveColor: Color {
        MHBTheme.ColorToken.primary.color
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous)
                        .fill(Color(uiColor: .secondarySystemGroupedBackground))

                    TextEditor(text: $note)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, MHBTheme.Spacing.s3)
                        .padding(.vertical, MHBTheme.Spacing.s3)
                        .focused($isFocused)

                    if note.isEmpty {
                        Text("记录这只宠物的特殊习惯、照护提醒或想补充的信息")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
                            .padding(.horizontal, MHBTheme.Spacing.s4)
                            .padding(.vertical, MHBTheme.Spacing.s4)
                            .allowsHitTesting(false)
                    }

                    Text("\(note.count)/\(noteLimit)")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
                        .monospacedDigit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                        .padding(MHBTheme.Spacing.s4)
                }
                .frame(minHeight: 220)

                Text("备注仅用于宠物档案展示和照护提醒。")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)

                Spacer()
            }
            .padding(.horizontal, MHBTheme.Spacing.s4)
            .padding(.top, MHBTheme.Spacing.s4)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("编辑备注")
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
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .background(MHBPresentationDismissObserver(onWillDismiss: onWillDismiss))
        .onAppear {
            isFocused = true
        }
        .onChange(of: note) { _, newValue in
            if newValue.count > noteLimit {
                note = String(newValue.prefix(noteLimit))
            }
        }
    }

    private func saveIfNeeded() {
        note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        onWillDismiss()
        onSave()
        dismiss()
    }
}
