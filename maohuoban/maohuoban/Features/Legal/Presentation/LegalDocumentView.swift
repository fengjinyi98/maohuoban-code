import SwiftUI
import MaohuobanDesignSystem

// LegalDocumentView 法务文档 Sheet
// 核心职责：
// - 承载用户协议和隐私政策的后端 HTML 内容
// - 管理关闭、加载、错误与重试入口
struct LegalDocumentView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: LegalDocumentViewModel

    init(
        kind: LegalDocumentKind,
        repository: LegalRepository = DefaultLegalRepository()
    ) {
        _viewModel = State(initialValue: LegalDocumentViewModel(kind: kind, repository: repository))
    }

    var body: some View {
        VStack(spacing: 0) {
            LegalDocumentNavigationBar(
                title: viewModel.document?.title ?? viewModel.kind.fallbackTitle,
                onClose: { dismiss() }
            )

            Divider()
                .overlay(MHBTheme.ColorToken.separator.color)

            LegalDocumentContentView(
                document: viewModel.document,
                isLoading: viewModel.isLoading,
                errorMessage: viewModel.errorMessage,
                onRetry: {
                    Task { await viewModel.load() }
                }
            )
        }
        .background(MHBTheme.ColorToken.background.color.ignoresSafeArea())
        .task {
            await viewModel.load()
        }
    }
}

// LegalDocumentNavigationBar 法务文档导航栏
// 核心职责：
// - 展示后端文档标题
// - 提供稳定的关闭按钮
private struct LegalDocumentNavigationBar: View {
    let title: String
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s3) {
            Text(title)
                .font(MHBTheme.Typography.headline)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    .frame(width: 36, height: 36)
                    .background(MHBTheme.ColorToken.cardSolid.color, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("关闭")
            .accessibilityIdentifier("legal.closeButton")
        }
        .padding(.horizontal, MHBTheme.Spacing.s5)
        .padding(.vertical, MHBTheme.Spacing.s3)
        .background(MHBTheme.ColorToken.background.color)
    }
}

// LegalDocumentContentView 法务文档内容区
// 核心职责：
// - 根据加载状态切换进度、错误和 HTML 内容
// - 让后端 HTML 成为唯一正文来源
private struct LegalDocumentContentView: View {
    let document: LegalDocument?
    let isLoading: Bool
    let errorMessage: String?
    let onRetry: () -> Void

    var body: some View {
        if let document {
            LegalHTMLWebView(html: document.html)
                .accessibilityIdentifier("legal.documentWebView")
        } else if isLoading {
            LegalDocumentLoadingView()
        } else {
            LegalDocumentErrorView(
                message: errorMessage ?? "文档加载失败，请稍后再试",
                onRetry: onRetry
            )
        }
    }
}

// LegalDocumentLoadingView 法务文档加载态
// 核心职责：
// - 展示协议文档读取中的轻量反馈
// - 保持 Sheet 内容区布局稳定
private struct LegalDocumentLoadingView: View {
    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s3) {
            Spacer()
            ProgressView()
                .tint(MHBTheme.ColorToken.primary.color)
            Text("正在加载文档")
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// LegalDocumentErrorView 法务文档错误态
// 核心职责：
// - 展示后端文档读取失败原因
// - 提供显式重试入口
private struct LegalDocumentErrorView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s4) {
            Spacer()
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)

            Text(message)
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                .multilineTextAlignment(.center)

            Button("重试", action: onRetry)
                .font(MHBTheme.Typography.callout.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, MHBTheme.Spacing.s5)
                .frame(height: 40)
                .background(MHBTheme.ColorToken.primary.color, in: .rect(cornerRadius: MHBTheme.Radius.medium))
            Spacer()
        }
        .padding(MHBTheme.Spacing.s5)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
