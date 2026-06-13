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
        LegalDocumentContentView(
            document: viewModel.document,
            isLoading: viewModel.isLoading,
            errorMessage: viewModel.errorMessage,
            onRetry: {
                Task { await viewModel.load() }
            }
        )
        .ignoresSafeArea(edges: .top)
        .background(MHBTheme.ColorToken.background.color.ignoresSafeArea())
        .navigationTitle(viewModel.document?.title ?? viewModel.kind.fallbackTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .scrollEdgeEffectStyle(.soft, for: .top)
        .task {
            await viewModel.load()
        }
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
                .ignoresSafeArea(edges: .top)
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
