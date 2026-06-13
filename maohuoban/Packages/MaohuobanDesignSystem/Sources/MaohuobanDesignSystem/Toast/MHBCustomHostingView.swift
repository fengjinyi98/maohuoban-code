// MHBCustomHostingView.swift 自定义内容宿主视图控制器
// 核心职责：
// - 封装并托管渲染 MHBToastView 布局
// - 控制状态栏（StatusBar）的可控显示与隐藏以配合刘海屏

import SwiftUI
import UIKit

public final class MHBCustomHostingView: UIHostingController<MHBToastView> {
    public var isStatusBarHidden: Bool = false {
        didSet {
            setNeedsStatusBarAppearanceUpdate()
        }
    }

    public override var prefersStatusBarHidden: Bool {
        return isStatusBarHidden
    }
}
