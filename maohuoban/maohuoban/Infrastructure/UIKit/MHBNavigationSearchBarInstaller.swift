import SwiftUI
import UIKit

// MHBNavigationSearchBarInstaller 导航栏搜索框安装器
// 核心职责：
// - 在 UIKit 生命周期中把 UISearchController 安装到当前 UINavigationItem
// - 复用系统集成式搜索栏布局和原生 Liquid Glass 外观
struct MHBNavigationSearchBarInstaller: UIViewControllerRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool

    let dismissRequestNonce: Int
    let prompt: String
    let tintColor: UIColor
    let textColor: UIColor
    let accessibilityIdentifier: String
    let onSubmit: () -> Void

    func makeUIViewController(context: Context) -> InstallerViewController {
        InstallerViewController(coordinator: context.coordinator)
    }

    func updateUIViewController(
        _ uiViewController: InstallerViewController,
        context: Context
    ) {
        context.coordinator.parent = self
        uiViewController.coordinator = context.coordinator
        uiViewController.scheduleInstallSearchBar()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    static func dismantleUIViewController(
        _ uiViewController: InstallerViewController,
        coordinator: Coordinator
    ) {
        coordinator.uninstall()
    }

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
                coordinator.logMissingNavigationController()
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

    // Coordinator 搜索控制器事件协调器
    // 核心职责：
    // - 管理 UISearchController 生命周期和导航栏状态还原
    // - 将 UIKit 搜索输入事件同步回 SwiftUI 状态
    final class Coordinator: NSObject, UISearchBarDelegate, UISearchResultsUpdating {
        var parent: MHBNavigationSearchBarInstaller
        private let searchController = UISearchController(searchResultsController: nil)
        private weak var installedNavigationController: UINavigationController?
        private weak var installedNavigationItem: UINavigationItem?
        private var previousSearchController: UISearchController?
        private var previousPreferredSearchBarPlacement: UINavigationItem.SearchBarPlacement = .automatic
        private var previousHidesSearchBarWhenScrolling = true
        private var previousAllowsToolbarIntegration = true
        private var previousLeftItemsSupplementBackButton = false
        private var previousLeadingItemGroups: [UIBarButtonItemGroup] = []
        private var previousTitle: String?
        private var lastInstallLogSignature: String?
        private var hasLoggedMissingNavigationController = false
        private var handledDismissRequestNonce = 0
        private var activeSearchBarWidthConstraint: NSLayoutConstraint?

        init(parent: MHBNavigationSearchBarInstaller) {
            self.parent = parent
            super.init()
            configureSearchController()
        }

        func install(
            on navigationController: UINavigationController,
            containing view: UIView
        ) {
            let targetViewController = targetViewController(
                in: navigationController,
                containing: view
            )
            guard let navigationItem = targetViewController?.navigationItem else {
                return
            }

            if installedNavigationItem !== navigationItem {
                uninstall()
                previousSearchController = navigationItem.searchController
                previousPreferredSearchBarPlacement = navigationItem.preferredSearchBarPlacement
                previousHidesSearchBarWhenScrolling = navigationItem.hidesSearchBarWhenScrolling
                previousAllowsToolbarIntegration = navigationItem.searchBarPlacementAllowsToolbarIntegration
                previousLeftItemsSupplementBackButton = navigationItem.leftItemsSupplementBackButton
                previousLeadingItemGroups = navigationItem.leadingItemGroups
                previousTitle = navigationItem.title
                installedNavigationController = navigationController
                installedNavigationItem = navigationItem
            }

            applyConfiguration()

            if navigationItem.searchController !== searchController {
                navigationItem.searchController = searchController
            }
            navigationItem.preferredSearchBarPlacement = .integrated
            navigationItem.searchBarPlacementAllowsToolbarIntegration = true
            navigationItem.hidesSearchBarWhenScrolling = false
            navigationItem.leftItemsSupplementBackButton = true
            navigationItem.leadingItemGroups = [
                navigationItem.searchBarPlacementBarButtonItem.creatingFixedGroup()
            ]
            navigationItem.title = nil

            applyState()
            updateSearchBarPlacementWidth(
                navigationItem: navigationItem,
                navigationController: navigationController
            )
            logInstall(
                navigationItem: navigationItem,
                navigationController: navigationController,
                targetViewController: targetViewController
            )
        }

        func uninstall() {
            guard let installedNavigationItem else {
                return
            }

            if installedNavigationItem.searchController === searchController {
                installedNavigationItem.searchController = previousSearchController
                installedNavigationItem.preferredSearchBarPlacement = previousPreferredSearchBarPlacement
                installedNavigationItem.hidesSearchBarWhenScrolling = previousHidesSearchBarWhenScrolling
                installedNavigationItem.searchBarPlacementAllowsToolbarIntegration = previousAllowsToolbarIntegration
                installedNavigationItem.leftItemsSupplementBackButton = previousLeftItemsSupplementBackButton
                installedNavigationItem.leadingItemGroups = previousLeadingItemGroups
                installedNavigationItem.title = previousTitle
            }

            searchController.searchBar.resignFirstResponder()
            searchController.isActive = false
            removeActiveSearchBarWidth()
            installedNavigationController = nil
            self.installedNavigationItem = nil
            previousSearchController = nil
            previousPreferredSearchBarPlacement = .automatic
            previousHidesSearchBarWhenScrolling = true
            previousAllowsToolbarIntegration = true
            previousLeftItemsSupplementBackButton = false
            previousLeadingItemGroups = []
            previousTitle = nil
        }

        func logMissingNavigationController() {
            #if DEBUG
            guard !hasLoggedMissingNavigationController else {
                return
            }

            hasLoggedMissingNavigationController = true
            print("[DEBUG:SearchBarTitleView] missing navigationController")
            #endif
        }

        func updateSearchResults(for searchController: UISearchController) {
            let nextText = searchController.searchBar.text ?? ""
            guard nextText != parent.text else {
                return
            }

            parent.text = nextText
        }

        func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
            parent.isFocused = true
            updateSearchBarPlacementWidth()
        }

        func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
            parent.isFocused = false
            updateSearchBarPlacementWidth()
        }

        func searchBar(
            _ searchBar: UISearchBar,
            textDidChange searchText: String
        ) {
            parent.text = searchText
        }

        func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
            parent.text = searchBar.text ?? ""
            parent.onSubmit()
            dismissSearchBar(reason: "submit", shouldLogIfIdle: true)
        }

        func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
            parent.text = searchBar.text ?? ""
            parent.isFocused = false
            dismissSearchBar(reason: "cancelButton", shouldLogIfIdle: true)
        }

        private func configureSearchController() {
            searchController.searchResultsUpdater = self
            searchController.obscuresBackgroundDuringPresentation = false
            searchController.automaticallyShowsSearchResultsController = false
            searchController.automaticallyShowsCancelButton = true
            searchController.hidesNavigationBarDuringPresentation = false

            let searchBar = searchController.searchBar
            searchBar.delegate = self
            searchBar.searchBarStyle = .prominent
            searchBar.autocapitalizationType = .none
            searchBar.returnKeyType = .search
            searchBar.enablesReturnKeyAutomatically = false
            searchBar.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            searchBar.setContentHuggingPriority(.defaultLow, for: .horizontal)
        }

        private func applyConfiguration() {
            let searchBar = searchController.searchBar
            searchBar.placeholder = parent.prompt
            searchBar.tintColor = parent.tintColor
            searchBar.accessibilityIdentifier = parent.accessibilityIdentifier
            searchBar.searchTextField.textColor = parent.textColor
        }

        private func applyState() {
            let searchBar = searchController.searchBar
            if searchBar.text != parent.text {
                searchBar.text = parent.text
            }

            if handledDismissRequestNonce != parent.dismissRequestNonce {
                handledDismissRequestNonce = parent.dismissRequestNonce
                dismissSearchBar(
                    reason: "request:\(parent.dismissRequestNonce)",
                    shouldLogIfIdle: true
                )
                return
            }

            if parent.isFocused {
                requestFocusIfPossible()
            } else {
                dismissSearchBar(reason: "focusState", shouldLogIfIdle: false)
            }
        }

        private func requestFocusIfPossible() {
            let searchBar = searchController.searchBar
            guard searchBar.window != nil else {
                return
            }

            if !searchController.isActive {
                searchController.isActive = true
            }
            updateSearchBarPlacementWidth()

            guard !searchBar.searchTextField.isFirstResponder else {
                return
            }

            searchBar.becomeFirstResponder()
        }

        private func dismissSearchBar(
            reason: String,
            shouldLogIfIdle: Bool
        ) {
            let searchBar = searchController.searchBar
            let wasActive = searchController.isActive
            let wasSearchBarFirstResponder = searchBar.isFirstResponder
            let wasTextFieldFirstResponder = searchBar.searchTextField.isFirstResponder
            let shouldLog = shouldLogIfIdle
                || wasActive
                || wasSearchBarFirstResponder
                || wasTextFieldFirstResponder

            searchBar.endEditing(true)
            searchBar.searchTextField.resignFirstResponder()
            searchBar.resignFirstResponder()
            searchController.isActive = false
            updateSearchBarPlacementWidth()

            #if DEBUG
            if shouldLog {
                print(
                    "[DEBUG:SearchKeyboardDismiss] handled "
                    + "reason=\(reason) "
                    + "wasActive=\(wasActive) "
                    + "wasSearchBarFirstResponder=\(wasSearchBarFirstResponder) "
                    + "wasTextFieldFirstResponder=\(wasTextFieldFirstResponder) "
                    + "active=\(searchController.isActive) "
                    + "searchBarFirstResponder=\(searchBar.isFirstResponder) "
                    + "textFieldFirstResponder=\(searchBar.searchTextField.isFirstResponder) "
                    + "hasWindow=\(searchBar.window != nil)"
                )
            }
            #endif
        }

        private func updateSearchBarPlacementWidth() {
            guard
                let installedNavigationItem,
                let installedNavigationController
            else {
                return
            }

            updateSearchBarPlacementWidth(
                navigationItem: installedNavigationItem,
                navigationController: installedNavigationController
            )
        }

        private func updateSearchBarPlacementWidth(
            navigationItem: UINavigationItem,
            navigationController: UINavigationController
        ) {
            let placementItem = navigationItem.searchBarPlacementBarButtonItem
            if searchController.isActive {
                let activeWidth = activeSearchBarPlacementWidth(in: navigationController)
                placementItem.width = activeWidth
                applyActiveSearchBarWidth(activeWidth)
            } else {
                placementItem.width = 0
                removeActiveSearchBarWidth()
            }

            navigationController.navigationBar.setNeedsLayout()
        }

        private func applyActiveSearchBarWidth(_ width: CGFloat) {
            let searchBar = searchController.searchBar
            let widthConstraint: NSLayoutConstraint
            if let activeSearchBarWidthConstraint {
                widthConstraint = activeSearchBarWidthConstraint
            } else {
                widthConstraint = searchBar.widthAnchor.constraint(equalToConstant: width)
                widthConstraint.priority = UILayoutPriority(999)
                activeSearchBarWidthConstraint = widthConstraint
                widthConstraint.isActive = true
            }

            widthConstraint.constant = width
        }

        private func removeActiveSearchBarWidth() {
            activeSearchBarWidthConstraint?.isActive = false
            activeSearchBarWidthConstraint = nil
        }

        private func activeSearchBarPlacementWidth(
            in navigationController: UINavigationController
        ) -> CGFloat {
            let boundsWidth = navigationController.view.bounds.width
            let safeAreaInsets = navigationController.view.safeAreaInsets
            let availableWidth = boundsWidth - safeAreaInsets.left - safeAreaInsets.right
            let horizontalMargin: CGFloat = 16
            let cancelButtonReservedWidth: CGFloat = 56
            return max(
                180,
                availableWidth - horizontalMargin * 2 - cancelButtonReservedWidth
            )
        }

        private func targetViewController(
            in navigationController: UINavigationController,
            containing view: UIView
        ) -> UIViewController? {
            navigationController.viewControllers
                .reversed()
                .first { view.isDescendant(of: $0.view) }
            ?? navigationController.topViewController
        }

        private func logInstall(
            navigationItem: UINavigationItem,
            navigationController: UINavigationController,
            targetViewController: UIViewController?
        ) {
            #if DEBUG
            let searchBar = searchController.searchBar
            let targetName = targetViewController
                .map { String(describing: type(of: $0)) }
            ?? "nil"
            let signature = [
                targetName,
                String(describing: navigationItem.searchBarPlacement),
                searchBar.window == nil ? "noWindow" : "hasWindow",
                String(searchController.isActive),
                String(navigationItem.leadingItemGroups.count),
                String(Int(navigationItem.searchBarPlacementBarButtonItem.width.rounded())),
                String(Int(activeSearchBarWidthConstraint?.constant.rounded() ?? 0))
            ].joined(separator: "|")

            guard signature != lastInstallLogSignature else {
                return
            }

            lastInstallLogSignature = signature
            print(
                "[DEBUG:SearchBarTitleView] installed target=\(targetName) "
                + "placement=\(navigationItem.searchBarPlacement) "
                + "searchBarFrame=\(rectDescription(searchBar.frame)) "
                + "textFieldFrame=\(rectDescription(searchBar.searchTextField.frame)) "
                + "active=\(searchController.isActive) "
                + "leadingGroups=\(navigationItem.leadingItemGroups.count) "
                + "itemWidth=\(Int(navigationItem.searchBarPlacementBarButtonItem.width.rounded())) "
                + "constraintWidth=\(Int(activeSearchBarWidthConstraint?.constant.rounded() ?? 0)) "
                + "navWidth=\(Int(navigationController.view.bounds.width.rounded())) "
                + "hasWindow=\(searchBar.window != nil)"
            )
            #endif
        }

        private func rectDescription(_ rect: CGRect) -> String {
            let x = Int(rect.minX.rounded())
            let y = Int(rect.minY.rounded())
            let width = Int(rect.width.rounded())
            let height = Int(rect.height.rounded())
            return "{x:\(x),y:\(y),w:\(width),h:\(height)}"
        }
    }
}
