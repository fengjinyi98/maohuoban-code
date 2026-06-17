import SwiftUI
import MaohuobanDesignSystem

// PetProfileTagsEditorSheet 宠物性格标签编辑弹层
// 核心职责：
// - 通过统一标签组件编辑宠物性格标签
// - 支持推荐标签选择和自定义标签追加
struct PetProfileTagsEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var tags: [String]
    let suggestions: [String]
    let onWillDismiss: () -> Void
    let onSave: () -> Void

    @State private var customTag = ""

    private let tagLimit = 8
    private let customTagLimit = 8
    private let columns = [
        GridItem(.adaptive(minimum: 76), spacing: MHBTheme.Spacing.s2, alignment: .leading)
    ]

    private var normalizedCustomTag: String {
        customTag.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canAddCustomTag: Bool {
        !normalizedCustomTag.isEmpty
            && !tags.contains(normalizedCustomTag)
            && tags.count < tagLimit
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: MHBTheme.Spacing.s4) {
                    selectedTagsSection
                    suggestionTagsSection
                    customTagSection
                }
                .padding(.horizontal, MHBTheme.Spacing.s4)
                .padding(.top, MHBTheme.Spacing.s4)
                .padding(.bottom, MHBTheme.Spacing.s6)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("编辑性格标签")
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
                        onWillDismiss()
                        onSave()
                        dismiss()
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(MHBTheme.ColorToken.primary.color)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .background(MHBPresentationDismissObserver(onWillDismiss: onWillDismiss))
        .onChange(of: customTag) { _, newValue in
            if newValue.count > customTagLimit {
                customTag = String(newValue.prefix(customTagLimit))
            }
        }
    }

    private var selectedTagsSection: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
            Text("已选择")
                .font(MHBTheme.Typography.footnote)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)

            if tags.isEmpty {
                Text("暂未设置")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            } else {
                LazyVGrid(columns: columns, alignment: .leading, spacing: MHBTheme.Spacing.s2) {
                    ForEach(tags, id: \.self) { tag in
                        Button {
                            tags.removeAll { $0 == tag }
                        } label: {
                            MHBTagView(tag, systemImage: "xmark", style: .primary, size: .medium)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var suggestionTagsSection: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
            Text("推荐标签")
                .font(MHBTheme.Typography.footnote)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)

            LazyVGrid(columns: columns, alignment: .leading, spacing: MHBTheme.Spacing.s2) {
                ForEach(suggestions, id: \.self) { suggestion in
                    let isSelected = tags.contains(suggestion)

                    Button {
                        toggleTag(suggestion)
                    } label: {
                        if isSelected {
                            MHBTagView(suggestion, systemImage: "checkmark", style: .primary, size: .medium)
                        } else {
                            MHBTagView(suggestion, style: .neutral, size: .medium)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(!isSelected && tags.count >= tagLimit)
                }
            }
        }
    }

    private var customTagSection: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
            Text("自定义标签")
                .font(MHBTheme.Typography.footnote)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)

            HStack(alignment: .center, spacing: MHBTheme.Spacing.s3) {
                TextField("输入标签", text: $customTag)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .onSubmit(addCustomTagIfNeeded)

                Button("添加") {
                    addCustomTagIfNeeded()
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.primary.color.opacity(canAddCustomTag ? 1 : 0.35))
                .disabled(!canAddCustomTag)
            }
            .padding(.horizontal, MHBTheme.Spacing.s4)
            .frame(minHeight: 52)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))

            Text("最多选择 \(tagLimit) 个标签，每个标签最多 \(customTagLimit) 个字符。")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
        }
    }

    private func toggleTag(_ tag: String) {
        if tags.contains(tag) {
            tags.removeAll { $0 == tag }
        } else if tags.count < tagLimit {
            tags.append(tag)
        }
    }

    private func addCustomTagIfNeeded() {
        guard canAddCustomTag else { return }
        tags.append(normalizedCustomTag)
        customTag = ""
    }
}
