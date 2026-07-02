import SwiftUI
import MaohuobanDesignSystem

// PetWeightRecordSheet 体重记录弹层
// 核心职责：
// - 通过原生 sheet 收集体重事实记录
// - 承载体重输入、记录时间和场景标签选择
struct PetWeightRecordSheet: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isWeightFocused: Bool

    let petName: String
    let initialWeightText: String

    @State private var weightText: String
    @State private var recordedAt = Date()
    @State private var selectedContext = PetWeightRecordContext.routine

    private let weightLimit = 6

    init(
        petName: String,
        initialWeightText: String
    ) {
        self.petName = petName
        self.initialWeightText = initialWeightText
        self._weightText = State(initialValue: initialWeightText)
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

                    PetWeightRecordContextSection(selectedContext: $selectedContext)
                }

                Spacer(minLength: MHBTheme.Spacing.s5)

                Button {
                    saveRecord()
                } label: {
                    Text("保存事实记录")
                        .font(MHBTheme.Typography.callout.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(saveButtonColor, in: RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(!isWeightValid)
                .padding(.horizontal, MHBTheme.Spacing.s5)
                .padding(.bottom, MHBTheme.Spacing.s5)
            }
            .background(MHBTheme.ColorToken.background.color)
            .navigationTitle(petName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("关闭")
                }
            }
        }
        .presentationDetents([.height(520), .large])
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

    private var isWeightValid: Bool {
        guard !trimmedWeight.isEmpty else { return false }
        return Double(trimmedWeight) != nil
    }

    private var saveButtonColor: Color {
        MHBTheme.ColorToken.primary.color.opacity(isWeightValid ? 1 : 0.35)
    }

    private func saveRecord() {
        guard isWeightValid else { return }
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

// PetWeightRecordContext 体重记录场景
// 核心职责：
// - 定义体重记录 sheet 的低摩擦场景标签
private enum PetWeightRecordContext: String, CaseIterable, Hashable {
    case routine
    case daily
    case hospital
    case grooming
    case checkup

    var title: String {
        switch self {
        case .routine:
            "例行称重"
        case .daily:
            "日常称重"
        case .hospital:
            "医院就诊"
        case .grooming:
            "洗澡美容"
        case .checkup:
            "驱虫/体检"
        }
    }
}

// PetWeightRecordInputStage 体重输入区域
// 核心职责：
// - 展示大字号体重输入框
// - 保持 kg 单位和数字键盘输入体验
private struct PetWeightRecordInputStage: View {
    @Binding var weightText: String
    var isFocused: FocusState<Bool>.Binding

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: MHBTheme.Spacing.s2) {
            TextField("4.20", text: $weightText)
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused(isFocused)
                .frame(width: 178)

            Text("kg")
                .font(MHBTheme.Typography.title.weight(.semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, MHBTheme.Spacing.s5)
        .padding(.bottom, MHBTheme.Spacing.s6)
        .padding(.horizontal, MHBTheme.Spacing.s5)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(MHBTheme.ColorToken.separatorSoft.color)
                .frame(height: 1)
                .padding(.horizontal, MHBTheme.Spacing.s5)
        }
    }
}

// PetWeightRecordDateRow 体重记录时间行
// 核心职责：
// - 使用系统 DatePicker 选择记录时间
// - 保持行式表单的信息密度
private struct PetWeightRecordDateRow: View {
    @Binding var recordedAt: Date

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s3) {
            Image(systemName: "calendar")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.primary.color)
                .frame(width: 28, height: 28)
                .background(MHBTheme.ColorToken.separatorSoft.color, in: RoundedRectangle(cornerRadius: MHBTheme.Radius.small, style: .continuous))

            Text("记录时间")
                .font(MHBTheme.Typography.callout.weight(.medium))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

            Spacer()

            DatePicker(
                "记录时间",
                selection: $recordedAt,
                displayedComponents: [.date, .hourAndMinute]
            )
            .labelsHidden()
        }
        .padding(.horizontal, MHBTheme.Spacing.s5)
        .frame(height: 68)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(MHBTheme.ColorToken.separatorSoft.color)
                .frame(height: 1)
                .padding(.leading, MHBTheme.Spacing.s5)
        }
    }
}

// PetWeightRecordContextSection 体重记录场景区域
// 核心职责：
// - 展示可选场景标签
// - 维护单选状态以降低记录输入成本
private struct PetWeightRecordContextSection: View {
    @Binding var selectedContext: PetWeightRecordContext

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
            Text("体重记录场景（选填）")
                .font(MHBTheme.Typography.caption.weight(.medium))
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)

            MHBFlowLayout(
                horizontalSpacing: MHBTheme.Spacing.s2,
                verticalSpacing: MHBTheme.Spacing.s2
            ) {
                ForEach(PetWeightRecordContext.allCases, id: \.self) { context in
                    PetWeightRecordContextChip(
                        title: "# \(context.title)",
                        isSelected: selectedContext == context,
                        action: {
                            selectedContext = context
                        }
                    )
                }
            }
        }
        .padding(.horizontal, MHBTheme.Spacing.s5)
        .padding(.top, MHBTheme.Spacing.s4)
    }
}

// PetWeightRecordContextChip 体重记录场景标签
// 核心职责：
// - 展示场景标签选中态
// - 承载单个标签点击动作
private struct PetWeightRecordContextChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(MHBTheme.Typography.caption.weight(isSelected ? .semibold : .medium))
                .foregroundStyle(
                    isSelected
                        ? MHBTheme.ColorToken.primary.color
                        : MHBTheme.ColorToken.labelSecondary.color
                )
                .padding(.horizontal, MHBTheme.Spacing.s3)
                .frame(height: 34)
                .background(chipBackground, in: RoundedRectangle(cornerRadius: MHBTheme.Radius.small, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: MHBTheme.Radius.small, style: .continuous)
                        .strokeBorder(chipBorderColor, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }

    private var chipBackground: Color {
        isSelected
            ? MHBTheme.ColorToken.primary.color.opacity(0.10)
            : MHBTheme.ColorToken.separatorSoft.color
    }

    private var chipBorderColor: Color {
        isSelected
            ? MHBTheme.ColorToken.primary.color.opacity(0.22)
            : Color.clear
    }
}
