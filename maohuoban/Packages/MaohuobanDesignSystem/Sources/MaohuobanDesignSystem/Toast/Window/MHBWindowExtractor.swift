// MHBWindowExtractor.swift 窗口层级提取器
// 核心职责：
// - 通过 UIViewRepresentable 在视图层级中捕获底层的 UIWindow 实例
// - 提供安全回调暴露提取到的窗口对象

import SwiftUI
import UIKit

public struct MHBWindowExtractor: UIViewRepresentable {
    public var result: (UIWindow) -> Void

    public init(result: @escaping (UIWindow) -> Void) {
        self.result = result
    }

    public func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear
        DispatchQueue.main.async {
            if let window = view.window {
                result(window)
            }
        }
        return view
    }

    public func updateUIView(_ uiView: UIView, context: Context) {}
}
