import SwiftUI
import MaohuobanDesignSystem

// ProfileUserBioEditorSheet 用户个人简介编辑弹层
// 核心职责：
// - 承载个人简介的多行输入草稿
// - 统一简介字数限制和保存行为
struct ProfileUserBioEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var bio: String
    let policyText: String?
    let onWillDismiss: () -> Void
    let onSave: () -> Void

    @FocusState private var isFocused: Bool

    private let bioLimit = 100

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous)
                        .fill(Color(uiColor: .secondarySystemGroupedBackground))

                    TextEditor(text: $bio)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, MHBTheme.Spacing.s3)
                        .padding(.vertical, MHBTheme.Spacing.s3)
                        .focused($isFocused)
                        .accessibilityIdentifier("profile.userEdit.bioEditor.input")

                    if bio.isEmpty {
                        Text("介绍你和毛伙伴的日常、照护经验或想让大家了解的信息")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
                            .padding(.horizontal, MHBTheme.Spacing.s4)
                            .padding(.vertical, MHBTheme.Spacing.s4)
                            .allowsHitTesting(false)
                    }

                    Text("\(bio.count)/\(bioLimit)")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
                        .monospacedDigit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                        .padding(MHBTheme.Spacing.s4)
                }
                .frame(minHeight: 220)

                VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
                    Text("简介会展示在个人主页资料区。")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)

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
            .navigationTitle("编辑简介")
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
                    .foregroundStyle(MHBTheme.ColorToken.primary.color)
                    .accessibilityIdentifier("profile.userEdit.bioEditor.saveButton")
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .background(MHBPresentationDismissObserver(onWillDismiss: onWillDismiss))
        .onAppear {
            isFocused = true
        }
        .onChange(of: bio) { _, newValue in
            if newValue.count > bioLimit {
                bio = String(newValue.prefix(bioLimit))
            }
        }
        .accessibilityIdentifier("profile.userEdit.bioEditor.sheet")
    }

    private func saveIfNeeded() {
        bio = bio.trimmingCharacters(in: .whitespacesAndNewlines)
        onWillDismiss()
        onSave()
        dismiss()
    }
}
