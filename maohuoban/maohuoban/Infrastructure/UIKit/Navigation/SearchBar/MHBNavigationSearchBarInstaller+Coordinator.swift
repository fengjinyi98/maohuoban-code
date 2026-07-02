import UIKit

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
        dismissSearchBar()
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        parent.text = searchBar.text ?? ""
        parent.isFocused = false
        dismissSearchBar()
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
            dismissSearchBar()
            return
        }

        if parent.isFocused {
            requestFocusIfPossible()
        } else {
            dismissSearchBar()
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

    private func dismissSearchBar() {
        let searchBar = searchController.searchBar
        searchBar.endEditing(true)
        searchBar.searchTextField.resignFirstResponder()
        searchBar.resignFirstResponder()
        searchController.isActive = false
        updateSearchBarPlacementWidth()
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
}
