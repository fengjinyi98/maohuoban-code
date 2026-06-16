import SwiftUI
import MaohuobanDesignSystem

// PetProfileDateEditorSheet 宠物日期编辑弹层
// 核心职责：
// - 使用系统 DatePicker 编辑宠物日期字段
// - 统一日期字段保存、关闭和导航栏样式
struct PetProfileDateEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    @Binding var date: Date
    let onWillDismiss: () -> Void
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s4) {
                DatePicker(
                    title,
                    selection: $date,
                    in: ...Date.now,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding(MHBTheme.Spacing.s3)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))

                Spacer()
            }
            .padding(.horizontal, MHBTheme.Spacing.s4)
            .padding(.top, MHBTheme.Spacing.s4)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(title)
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
    }
}

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
