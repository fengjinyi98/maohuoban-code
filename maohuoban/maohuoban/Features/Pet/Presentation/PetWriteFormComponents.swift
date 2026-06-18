import SwiftUI
import MaohuobanDesignSystem
import MaohuobanDiagnostics

// PetWriteFormSection 宠物写入表单分组
// 核心职责：
// - 提供创建与记录页面的表单分组样式
// - 统一 DesignSystem token 的间距、圆角和颜色
struct PetWriteFormSection<Content: View>: View {
    let title: LocalizedStringResource
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
            Text(title)
                .font(MHBTheme.Typography.headline)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

            content()
        }
        .padding(MHBTheme.Spacing.s4)
        .background(MHBTheme.ColorToken.cardSolid.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
    }
}

// PetWriteTextField 宠物写入文本输入行
// 核心职责：
// - 承载宠物表单中的单行文本输入
// - 统一输入标题、底色和可访问标识承接
struct PetWriteTextField: View {
    let title: LocalizedStringResource
    @Binding var text: String
    let prompt: LocalizedStringResource
    var diagnosticsID: String? = nil
    var diagnosticsForm: String? = nil
    var diagnosticsField: String? = nil
    var diagnosticsScreenName: String? = nil
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
            Text(title)
                .font(MHBTheme.Typography.caption)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
            TextField(title, text: $text, prompt: Text(prompt))
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($isFocused)
                .padding(MHBTheme.Spacing.s3)
                .background(MHBTheme.ColorToken.primaryBackgroundSoft.color)
                .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
        }
        .onChange(of: isFocused) { _, focused in
            recordTextFieldBoundary(focused: focused)
        }
    }

    private func recordTextFieldBoundary(focused: Bool) {
        guard let diagnosticsID,
              let diagnosticsForm,
              let diagnosticsField,
              let diagnosticsScreenName else {
            return
        }
        let event = DiagnosticsSwiftUIInstrumentation.textFieldBoundaryEvent(
            diagnosticsID: diagnosticsID,
            action: focused ? .focus : .blur,
            form: diagnosticsForm,
            field: diagnosticsField,
            screenName: diagnosticsScreenName,
            valueLength: text.count,
            valid: nil
        )
        Task {
            await Diagnostics.record(event)
        }
    }
}

// PetWriteSubmitButton 宠物写入提交按钮
// 核心职责：
// - 统一创建宠物和记录事件提交入口
// - 在提交中保持稳定尺寸和禁用态
struct PetWriteSubmitButton: View {
    let title: LocalizedStringResource
    let isSubmitting: Bool
    var diagnosticsID: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: instrumentedAction) {
            HStack(spacing: MHBTheme.Spacing.s2) {
                if isSubmitting {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: MHBTheme.IconSize.small, weight: .semibold))
                }

                Text(isSubmitting ? "保存中" : title)
                    .font(MHBTheme.Typography.headline)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(minHeight: MHBTheme.Spacing.s8 + MHBTheme.Spacing.s4)
            .background(MHBTheme.ColorToken.primary.color)
            .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
            .opacity(isSubmitting ? 0.65 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isSubmitting)
        .accessibilityIdentifier("pet.write.submitButton")
    }

    private func instrumentedAction() {
        if let diagnosticsID {
            Task {
                await Diagnostics.record(
                    DiagnosticsSwiftUIInstrumentation.componentEvent(
                        diagnosticsID: diagnosticsID,
                        component: .button,
                        action: .tap,
                        metadata: ["component_name": .string("PetWriteSubmitButton")]
                    )
                )
            }
        }
        action()
    }
}
