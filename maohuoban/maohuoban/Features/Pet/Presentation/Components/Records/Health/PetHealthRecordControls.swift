import SwiftUI
import MaohuobanDesignSystem

// PetHealthFormCard 健康记录表单卡片
// 核心职责：
// - 统一健康记录页面的白底表单容器
// - 提供稳定内边距、圆角和边框
struct PetHealthFormCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
            content()
        }
        .padding(MHBTheme.Spacing.s4)
        .background(MHBTheme.ColorToken.cardSolid.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.extraLarge, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MHBTheme.Radius.extraLarge, style: .continuous)
                .stroke(MHBTheme.ColorToken.separator.color, lineWidth: 1)
        }
    }
}

// PetHealthTextInputRow 健康记录单行输入
// 核心职责：
// - 统一图标、标题和右侧输入布局
// - 支持键盘类型按字段收敛
struct PetHealthTextInputRow: View {
    let title: LocalizedStringResource
    let systemImage: String?
    @Binding var text: String
    let prompt: LocalizedStringResource
    var keyboardType: UIKeyboardType

    init(
        title: LocalizedStringResource,
        systemImage: String? = nil,
        text: Binding<String>,
        prompt: LocalizedStringResource,
        keyboardType: UIKeyboardType = .default
    ) {
        self.title = title
        self.systemImage = systemImage
        self._text = text
        self.prompt = prompt
        self.keyboardType = keyboardType
    }

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s3) {
            if let systemImage = systemImage, !systemImage.isEmpty {
                Label(title, systemImage: systemImage)
                    .font(MHBTheme.Typography.callout)
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                    .labelStyle(.titleAndIcon)
            } else {
                Text(title)
                    .font(MHBTheme.Typography.callout)
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
            }

            Spacer(minLength: MHBTheme.Spacing.s2)

            TextField(title, text: $text, prompt: Text(prompt))
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .multilineTextAlignment(.trailing)
                .keyboardType(keyboardType)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
    }
}

// PetHealthMultilineInput 健康记录多行输入
// 核心职责：
// - 承载备注类长文本
// - 保持输入区域高度稳定并适配多行内容
struct PetHealthMultilineInput: View {
    let title: LocalizedStringResource
    @Binding var text: String
    let prompt: LocalizedStringResource

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
            Text(title)
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

            TextField(title, text: $text, prompt: Text(prompt), axis: .vertical)
                .lineLimit(3...5)
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .padding(MHBTheme.Spacing.s3)
                .background(MHBTheme.ColorToken.primaryBackgroundSoft.color)
                .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
        }
    }
}

// PetHealthProofUploader 健康凭证上传入口
// 核心职责：
// - 预留疫苗本、处方和检查单等凭证上传入口
// - 以禁用态表达当前页面暂未接入媒体上传
struct PetHealthProofUploader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
            HStack {
                Text("凭证图片")
                    .font(MHBTheme.Typography.callout)
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                Spacer()
                Text("疫苗本、处方或检查单")
                    .font(MHBTheme.Typography.caption)
                    .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
            }

            Button(action: {}) {
                VStack(spacing: MHBTheme.Spacing.s1) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: MHBTheme.IconSize.medium, weight: .semibold))
                    Text("上传凭证")
                        .font(MHBTheme.Typography.caption)
                }
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                .frame(width: 76, height: 76)
                .background(MHBTheme.ColorToken.primaryBackgroundSoft.color)
                .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous)
                        .stroke(MHBTheme.ColorToken.separator.color, style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                }
            }
            .buttonStyle(.plain)
            .disabled(true)
            .accessibilityLabel("上传凭证")
        }
    }
}

// PetHealthDivider 健康表单分割线
// 核心职责：
// - 提供健康记录行间轻量分割
// - 统一使用 DesignSystem 分割线 token
struct PetHealthDivider: View {
    var body: some View {
        Rectangle()
            .fill(MHBTheme.ColorToken.separatorSoft.color)
            .frame(height: 1)
    }
}
