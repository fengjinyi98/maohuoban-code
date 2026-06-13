import SwiftUI
import WebKit

// LegalHTMLWebView 法务 HTML WebView
// 核心职责：
// - 使用 WKWebView 渲染后端托管的协议 HTML
// - 避免相同 HTML 在 SwiftUI 更新时重复加载
struct LegalHTMLWebView: UIViewRepresentable {
    let html: String
    let safeAreaTop: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.accessibilityIdentifier = "legal.documentWebView"
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        guard context.coordinator.loadedHTML != html else { return }
        context.coordinator.loadedHTML = html
        
        let overrideStyle = """
        <style>
        body {
            background: transparent !important;
            padding-top: \(safeAreaTop + 16)px !important;
        }
        main {
            background: transparent !important;
            border: none !important;
            box-shadow: none !important;
            padding: 0 !important;
            border-radius: 0 !important;
        }
        </style>
        """
        uiView.loadHTMLString(html + overrideStyle, baseURL: nil)
    }

    final class Coordinator {
        var loadedHTML: String?
    }
}
