import SwiftUI
import UIKit

// PetWalkScreenLifecycleObserver 遛弯页面生命周期观察器
// 核心职责：
// - 在系统导航 pop 动画开始前通知业务页收起 sheet
// - sheet 展示期间禁用侧滑返回手势，强制走 handleBack 确保 sheet 先 dismiss 再 pop
struct PetWalkScreenLifecycleObserver: UIViewControllerRepresentable {
    let isSheetPresented: Bool
    let onWillDisappear: () -> Void

    func makeUIViewController(context: Context) -> Controller {
        Controller()
    }

    func updateUIViewController(_ controller: Controller, context: Context) {
        controller.onWillDisappear = onWillDisappear
        controller.isSheetPresented = isSheetPresented
    }

    final class Controller: UIViewController {
        var onWillDisappear: (() -> Void)?
        var isSheetPresented: Bool = false {
            didSet {
                guard oldValue != isSheetPresented else { return }
                navigationController?.interactivePopGestureRecognizer?.isEnabled = !isSheetPresented
            }
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            navigationController?.interactivePopGestureRecognizer?.isEnabled = !isSheetPresented
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            navigationController?.interactivePopGestureRecognizer?.isEnabled = true
            onWillDisappear?()
        }
    }
}
