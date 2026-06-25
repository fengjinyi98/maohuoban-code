import SwiftUI
import MaohuobanDesignSystem

// PetPreventiveCareTypeSection 疫苗驱虫类型选择区
// 核心职责：
// - 在疫苗和驱虫两类记录之间切换
// - 为后续字段默认值提供明确入口语义
struct PetPreventiveCareTypeSection: View {
    @Binding var selectedKind: PetPreventiveCareKind

    var body: some View {
        PetPreventiveCareFormSection(title: "类型") {
            Picker("类型", selection: $selectedKind) {
                Text("疫苗").tag(PetPreventiveCareKind.vaccine)
                Text("驱虫").tag(PetPreventiveCareKind.deworming)
            }
            .pickerStyle(.segmented)
        }
    }
}

// PetPreventiveCareNameSection 疫苗驱虫名称输入区
// 核心职责：
// - 收集疫苗名称或驱虫方案
// - 根据类型切换输入提示
struct PetPreventiveCareNameSection: View {
    let selectedKind: PetPreventiveCareKind
    @Binding var nameText: String
    var isNameFocused: FocusState<Bool>.Binding

    var body: some View {
        PetPreventiveCareFormSection(title: selectedKind == .vaccine ? "疫苗名称" : "驱虫方案") {
            PetPreventiveCareTextInputRow(
                title: selectedKind == .vaccine ? "名称" : "方案",
                systemImage: selectedKind.systemImage,
                text: $nameText,
                prompt: selectedKind == .vaccine ? "例如 妙三多、狂犬疫苗" : "例如 大宠爱、拜宠清"
            )
            .focused(isNameFocused)
        }
    }
}

// PetPreventiveCareDateSection 疫苗驱虫日期选择区
// 核心职责：
// - 收集记录完成时间
// - 使用系统 DatePicker 保持输入稳定
struct PetPreventiveCareDateSection: View {
    let title: String
    @Binding var date: Date

    var body: some View {
        PetPreventiveCareFormSection(title: title) {
            DatePicker(
                "日期",
                selection: $date,
                displayedComponents: [.date]
            )
            .font(MHBTheme.Typography.callout)
            .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
        }
    }
}

// PetPreventiveCareExecutionSection 疫苗驱虫执行方式区
// 核心职责：
// - 收集记录来源和执行主体
// - 根据执行方式显示医院、商家或其他来源输入
struct PetPreventiveCareExecutionSection: View {
    @Binding var selectedMethod: PetPreventiveCareExecutionMethod
    @Binding var executionName: String

    var body: some View {
        PetPreventiveCareFormSection(title: "执行方式") {
            LazyVGrid(columns: columns, spacing: MHBTheme.Spacing.s2) {
                ForEach(PetPreventiveCareExecutionMethod.allCases) { method in
                    PetPreventiveCareExecutionMethodButton(
                        method: method,
                        isSelected: selectedMethod == method
                    ) {
                        selectedMethod = method
                        executionName = ""
                    }
                }
            }

            if selectedMethod.needsSubjectInput {
                PetPreventiveCareDivider()

                PetPreventiveCareTextInputRow(
                    title: selectedMethod.subjectTitle,
                    systemImage: selectedMethod.systemImage,
                    text: $executionName,
                    prompt: selectedMethod.subjectPrompt
                )
            }
        }
    }

    private var columns: [GridItem] {
        [
            GridItem(.flexible(), spacing: MHBTheme.Spacing.s2),
            GridItem(.flexible(), spacing: MHBTheme.Spacing.s2)
        ]
    }
}

// PetPreventiveCareExecutionMethodButton 执行方式按钮
// 核心职责：
// - 展示单个执行方式选项
// - 表达选中态和点击区域
private struct PetPreventiveCareExecutionMethodButton: View {
    let method: PetPreventiveCareExecutionMethod
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: MHBTheme.Spacing.s2) {
                Image(systemName: method.systemImage)
                    .font(.system(size: 14, weight: .semibold))

                Text(method.title)
                    .font(MHBTheme.Typography.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .foregroundStyle(isSelected ? MHBTheme.ColorToken.primary.color : MHBTheme.ColorToken.labelSecondary.color)
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(
                isSelected ? MHBTheme.ColorToken.primary.color.opacity(0.12) : MHBTheme.ColorToken.labelQuaternary.color.opacity(0.24),
                in: RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous)
            )
        }
        .buttonStyle(.plain)
    }
}

// PetPreventiveCareReminderSection 疫苗驱虫提醒设置区
// 核心职责：
// - 控制是否为记录生成下次提醒
// - 收集下次提醒日期
struct PetPreventiveCareReminderSection: View {
    @Binding var isEnabled: Bool
    @Binding var reminderAt: Date

    var body: some View {
        PetPreventiveCareFormSection(title: "下次提醒") {
            Toggle("开启提醒", isOn: $isEnabled)
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

            if isEnabled {
                PetPreventiveCareDivider()

                DatePicker(
                    "提醒日期",
                    selection: $reminderAt,
                    displayedComponents: [.date]
                )
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
            }
        }
    }
}

// PetPreventiveCareNoteSection 疫苗驱虫备注区
// 核心职责：
// - 收集用户补充说明
// - 支持多行输入以记录批号、反应或注意事项
struct PetPreventiveCareNoteSection: View {
    @Binding var note: String

    var body: some View {
        PetPreventiveCareFormSection(title: "备注") {
            TextField("例如 疫苗本批号、用药后反应、医生说明", text: $note, axis: .vertical)
                .lineLimit(3...5)
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// PetPreventiveCarePhotoSection 疫苗驱虫照片区
// 核心职责：
// - 为疫苗本、药盒和医院单据预留照片入口
// - 在快速 UI 阶段用本地状态展示可选照片占位
struct PetPreventiveCarePhotoSection: View {
    @Binding var photoAssetNames: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
            Text("照片（可选）")
                .font(MHBTheme.Typography.callout.weight(.semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)

            HStack(spacing: MHBTheme.Spacing.s3) {
                Button {
                    photoAssetNames.append("mock-photo-\(photoAssetNames.count + 1)")
                } label: {
                    VStack(spacing: MHBTheme.Spacing.s2) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 20, weight: .semibold))

                        Text("添加")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    .frame(width: 72, height: 72)
                    .background(MHBTheme.ColorToken.labelQuaternary.color.opacity(0.22), in: RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
                }
                .buttonStyle(.plain)

                ForEach(photoAssetNames, id: \.self) { assetName in
                    RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous)
                        .fill(MHBTheme.ColorToken.primary.color.opacity(0.12))
                        .frame(width: 72, height: 72)
                        .overlay {
                            Image(systemName: "photo.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(MHBTheme.ColorToken.primary.color)
                        }
                        .accessibilityLabel(assetName)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// PetPreventiveCareFormSection 疫苗驱虫表单分组
// 核心职责：
// - 统一表单分组标题、卡片和间距
// - 保持新增记录 sheet 的视觉节奏稳定
private struct PetPreventiveCareFormSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
            Text(title)
                .font(MHBTheme.Typography.callout.weight(.semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)

            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .padding(MHBTheme.Spacing.s4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MHBTheme.ColorToken.cardSolid.color)
            .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
        }
    }
}

// PetPreventiveCareTextInputRow 疫苗驱虫文本输入行
// 核心职责：
// - 统一带图标的单行文本输入样式
// - 保持表单项标题和输入区域对齐
private struct PetPreventiveCareTextInputRow: View {
    let title: String
    let systemImage: String
    @Binding var text: String
    let prompt: String

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s3) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                .frame(width: 24)

            Text(title)
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

            Spacer(minLength: MHBTheme.Spacing.s3)

            TextField(prompt, text: $text)
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .multilineTextAlignment(.trailing)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
    }
}

// PetPreventiveCareDivider 疫苗驱虫表单分隔线
// 核心职责：
// - 为同一卡片内多行输入提供轻分隔
// - 使用设计系统 separator token
private struct PetPreventiveCareDivider: View {
    var body: some View {
        Rectangle()
            .fill(MHBTheme.ColorToken.separatorSoft.color)
            .frame(height: 1)
            .padding(.vertical, MHBTheme.Spacing.s3)
    }
}
