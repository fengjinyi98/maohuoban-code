import SwiftUI
import UIKit
import MaohuobanDesignSystem

// PetWorldFeedPager 宠物世界横滑分页容器
// 核心职责：
// - 使用 UIKit UIPageViewController 承载频道内容横向切换
// - 将 UIKit 滑动结果同步回 SwiftUI 频道选中态
struct PetWorldFeedPager: UIViewControllerRepresentable {
    let snapshot: PetWorldFeedSnapshot
    @Binding var selectedTab: PetWorldFeedTab
    let topContentInset: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIPageViewController {
        let controller = UIPageViewController(
            transitionStyle: .scroll,
            navigationOrientation: .horizontal
        )
        controller.dataSource = context.coordinator
        controller.delegate = context.coordinator
        clearUIKitBackgrounds(in: controller.view)
        return controller
    }

    func updateUIViewController(_ pageViewController: UIPageViewController, context: Context) {
        context.coordinator.parent = self
        context.coordinator.update(pageViewController: pageViewController)
        clearUIKitBackgrounds(in: pageViewController.view)
    }

    // clearUIKitBackgrounds 清理 UIKit 承载层默认背景
    // 核心职责：
    // - 避免 UIPageViewController 或内部 UIScrollView 在透明导航栏下露出系统背景
    // - 保持页面背景由 SwiftUI 内容层统一绘制
    private func clearUIKitBackgrounds(in view: UIView) {
        view.backgroundColor = .clear
        view.isOpaque = false

        for subview in view.subviews {
            clearUIKitBackgrounds(in: subview)
        }
    }

    // Coordinator UIKit 分页代理
    // 核心职责：
    // - 缓存各频道 SwiftUI HostingController
    // - 处理点击切换和手势滑动之间的双向状态同步
    final class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        var parent: PetWorldFeedPager

        private var controllers: [PetWorldFeedTab: UIHostingController<PetWorldFeedPageContent>] = [:]
        private var currentTab: PetWorldFeedTab?
        private var isProgrammaticTransition = false

        init(parent: PetWorldFeedPager) {
            self.parent = parent
        }

        func update(pageViewController: UIPageViewController) {
            guard let targetTab = resolvedSelectedTab else {
                return
            }

            if currentTab == nil {
                pageViewController.setViewControllers(
                    [controller(for: targetTab)],
                    direction: .forward,
                    animated: false
                )
                currentTab = targetTab
                return
            }

            guard currentTab != targetTab else {
                refreshVisibleController()
                return
            }

            let direction = transitionDirection(to: targetTab)
            isProgrammaticTransition = true

            pageViewController.setViewControllers(
                [controller(for: targetTab)],
                direction: direction,
                animated: true
            ) { [weak self] finished in
                guard let self else {
                    return
                }

                self.isProgrammaticTransition = false

                if finished {
                    self.currentTab = targetTab
                }
            }
        }

        func pageViewController(
            _ pageViewController: UIPageViewController,
            viewControllerBefore viewController: UIViewController
        ) -> UIViewController? {
            adjacentController(to: viewController, offset: -1)
        }

        func pageViewController(
            _ pageViewController: UIPageViewController,
            viewControllerAfter viewController: UIViewController
        ) -> UIViewController? {
            adjacentController(to: viewController, offset: 1)
        }

        func pageViewController(
            _ pageViewController: UIPageViewController,
            didFinishAnimating finished: Bool,
            previousViewControllers: [UIViewController],
            transitionCompleted completed: Bool
        ) {
            guard completed,
                  !isProgrammaticTransition,
                  let visibleController = pageViewController.viewControllers?.first,
                  let tab = tab(for: visibleController)
            else {
                return
            }

            currentTab = tab

            if parent.selectedTab != tab {
                parent.selectedTab = tab
            }
        }

        private var resolvedSelectedTab: PetWorldFeedTab? {
            if parent.snapshot.tabs.contains(parent.selectedTab) {
                return parent.selectedTab
            }

            return parent.snapshot.tabs.first
        }

        private func controller(for tab: PetWorldFeedTab) -> UIHostingController<PetWorldFeedPageContent> {
            let content = PetWorldFeedPageContent(
                page: PetWorldFeedPageContentResolver.page(
                    for: tab,
                    snapshot: parent.snapshot
                ),
                topContentInset: parent.topContentInset
            )

            if let controller = controllers[tab] {
                controller.rootView = content
                return controller
            }

            let controller = UIHostingController(rootView: content)
            controller.view.backgroundColor = .clear
            controller.view.isOpaque = false
            controllers[tab] = controller
            return controller
        }

        private func adjacentController(
            to viewController: UIViewController,
            offset: Int
        ) -> UIViewController? {
            guard let tab = tab(for: viewController),
                  let index = parent.snapshot.tabs.firstIndex(of: tab)
            else {
                return nil
            }

            let nextIndex = index + offset

            guard parent.snapshot.tabs.indices.contains(nextIndex) else {
                return nil
            }

            return controller(for: parent.snapshot.tabs[nextIndex])
        }

        private func tab(for viewController: UIViewController) -> PetWorldFeedTab? {
            controllers.first { _, controller in
                controller === viewController
            }?.key
        }

        private func transitionDirection(to targetTab: PetWorldFeedTab) -> UIPageViewController.NavigationDirection {
            guard let currentTab,
                  let currentIndex = parent.snapshot.tabs.firstIndex(of: currentTab),
                  let targetIndex = parent.snapshot.tabs.firstIndex(of: targetTab)
            else {
                return .forward
            }

            return targetIndex >= currentIndex ? .forward : .reverse
        }

        private func refreshVisibleController() {
            guard let currentTab else {
                return
            }

            _ = controller(for: currentTab)
        }
    }
}

// PetWorldFeedPageContent 宠物世界频道内容页
// 核心职责：
// - 渲染单个频道的提示标签和信息流卡片
// - 保持每个 UIKit 分页页面拥有独立纵向滚动上下文
struct PetWorldFeedPageContent: View {
    let page: PetWorldFeedPage
    let topContentInset: CGFloat

    var body: some View {
        MHBScreenScrollView {
            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s5) {
                PetWorldHintChipRail(chips: page.hintChips)

                LazyVStack(spacing: MHBTheme.Spacing.s4) {
                    ForEach(page.items) { item in
                        PetWorldFeedCard(item: item)
                    }
                }
            }
            .padding(.horizontal, MHBTheme.Spacing.s4)
            .padding(.top, topContentInset)
            .padding(.bottom, MHBTheme.Spacing.s8)
        }
        .background(MHBTheme.ColorToken.background.color)
    }
}
