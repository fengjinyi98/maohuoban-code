import SwiftUI
import MaohuobanDesignSystem

// ProfileUserGenderEditorSheet 用户性别编辑弹层
// 核心职责：
// - 承载用户性别单选草稿
// - 管理性别标签是否公开展示的本地开关
struct ProfileUserGenderEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedGender: ProfileUserEditGenderOption?
    @Binding var isGenderVisible: Bool
    @State private var draftGender: ProfileUserEditGenderOption?
    @State private var draftVisibility: Bool
    let onWillDismiss: () -> Void
    let onSave: () -> Void

    private let options = ProfileUserEditGenderOption.allCases

    init(
        selectedGender: Binding<ProfileUserEditGenderOption?>,
        isGenderVisible: Binding<Bool>,
        onWillDismiss: @escaping () -> Void,
        onSave: @escaping () -> Void = {}
    ) {
        self._selectedGender = selectedGender
        self._isGenderVisible = isGenderVisible
        self._draftGender = State(initialValue: selectedGender.wrappedValue)
        self._draftVisibility = State(initialValue: isGenderVisible.wrappedValue)
        self.onWillDismiss = onWillDismiss
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s4) {
                PetProfileEditSection {
                    ForEach(options) { option in
                        Button {
                            draftGender = option
                        } label: {
                            ProfileUserGenderOptionRow(
                                title: option.displayTitle,
                                isSelected: draftGender == option
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("profile.userEdit.genderEditor.option.\(option.rawValue)")

                        if option != options.last {
                            Rectangle()
                                .fill(MHBTheme.ColorToken.separatorSoft.color)
                                .frame(height: 0.5)
                                .padding(.horizontal, MHBTheme.Spacing.s4)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
                    Text("是否公开展示")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
                        .padding(.leading, MHBTheme.Spacing.s2)

                    PetProfileEditSection {
                        HStack(spacing: MHBTheme.Spacing.s3) {
                            Text("展示性别标签")
                                .font(.system(size: 16, weight: .regular))
                                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

                            Spacer()

                            Toggle("", isOn: $draftVisibility)
                                .labelsHidden()
                                .tint(MHBTheme.ColorToken.primary.color)
                                .accessibilityIdentifier("profile.userEdit.genderEditor.visibilityToggle")
                        }
                        .padding(.horizontal, MHBTheme.Spacing.s4)
                        .frame(minHeight: 52)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, MHBTheme.Spacing.s4)
            .padding(.top, MHBTheme.Spacing.s4)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("编辑性别")
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
                        selectedGender = draftGender
                        isGenderVisible = draftVisibility
                        onWillDismiss()
                        onSave()
                        dismiss()
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(MHBTheme.ColorToken.primary.color)
                    .accessibilityIdentifier("profile.userEdit.genderEditor.saveButton")
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .background(MHBPresentationDismissObserver(onWillDismiss: onWillDismiss))
        .accessibilityIdentifier("profile.userEdit.genderEditor.sheet")
    }
}

// ProfileUserGenderOptionRow 用户性别选项行
// 核心职责：
// - 展示单个性别选项
// - 为当前选中项展示勾选状态
private struct ProfileUserGenderOptionRow: View {
    let title: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s3) {
            Text(title)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

            Spacer()

            Image(systemName: "checkmark")
                .font(.system(size: MHBTheme.IconSize.small, weight: .bold))
                .foregroundStyle(MHBTheme.ColorToken.primary.color.opacity(isSelected ? 1 : 0))
        }
        .padding(.horizontal, MHBTheme.Spacing.s4)
        .frame(minHeight: 52)
        .contentShape(Rectangle())
    }
}
