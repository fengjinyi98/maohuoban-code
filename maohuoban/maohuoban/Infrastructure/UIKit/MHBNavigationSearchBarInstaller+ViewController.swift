import UIKit

// InstallerViewController 导航栏宿主探针
// 核心职责：
// - 查找当前 SwiftUI 页面所属的 UINavigationController
// - 在页面挂载和布局阶段触发搜索控制器安装
final class InstallerViewController: UIViewController {
    var coordinator: Coordinator
    private var hasScheduledInstall = false

    init(coordinator: Coordinator) {
        self.coordinator = coordinator
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
    }

    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        scheduleInstallSearchBar()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        scheduleInstallSearchBar()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        installSearchBar()
    }

    func scheduleInstallSearchBar() {
        installSearchBar()

        guard !hasScheduledInstall else {
            return
        }

        hasScheduledInstall = true
        Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            hasScheduledInstall = false
            installSearchBar()
        }
    }

    private func installSearchBar() {
        guard let navigationController = containingNavigationController() else {
            return
        }

        coordinator.install(on: navigationController, containing: view)
    }

    private func containingNavigationController() -> UINavigationController? {
        if let navigationController {
            return navigationController
        }

        var parentController = parent
        while let candidate = parentController {
            if let navigationController = candidate as? UINavigationController {
                return navigationController
            }

            if let navigationController = candidate.navigationController {
                return navigationController
            }

            parentController = candidate.parent
        }

        return Self.findNavigationController(containing: view, in: view.window?.rootViewController)
    }

    private static func findNavigationController(
        containing view: UIView,
        in controller: UIViewController?
    ) -> UINavigationController? {
        guard let controller else {
            return nil
        }

        if let navigationController = controller as? UINavigationController,
           view.isDescendant(of: navigationController.view) {
            return navigationController
        }

        if view.isDescendant(of: controller.view),
           let navigationController = controller.navigationController {
            return navigationController
        }

        if let tabBarController = controller as? UITabBarController,
           let navigationController = findNavigationController(
            containing: view,
            in: tabBarController.selectedViewController
           ) {
            return navigationController
        }

        for child in controller.children {
            if let navigationController = findNavigationController(
                containing: view,
                in: child
            ) {
                return navigationController
            }
        }

        if let presentedViewController = controller.presentedViewController {
            return findNavigationController(containing: view, in: presentedViewController)
        }

        return nil
    }
}
