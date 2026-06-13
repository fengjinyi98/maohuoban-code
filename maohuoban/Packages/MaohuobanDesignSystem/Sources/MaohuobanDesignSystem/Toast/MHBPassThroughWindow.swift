// MHBPassThroughWindow.swift 顶层穿透悬浮窗体
// 核心职责：
// - 在 WindowScene 上挂载用于显示 Toast 的独立层级窗体
// - 重写 hitTest 使得未命中 Toast 实体时能将手势穿透回底层窗口

import SwiftUI
import UIKit

@Observable
public final class MHBPassThroughWindow: UIWindow {
    public var toast: MHBToast? = nil
    public var isPresented: Bool = false

    public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let hitView = super.hitTest(point, with: event),
              let rootView = rootViewController?.view else {
            return nil
        }

        if #available(iOS 26, *) {
            if rootView.layer.hitTest(point)?.name == nil {
                return rootView
            }
            return nil
        } else {
            if #unavailable(iOS 18) {
                return hitView == rootView ? nil : hitView
            } else {
                for subview in rootView.subviews.reversed() {
                    let pointInSubview = subview.convert(point, from: rootView)
                    if subview.hitTest(pointInSubview, with: event) != nil {
                        return hitView
                    }
                }
                return nil
            }
        }
    }
}
