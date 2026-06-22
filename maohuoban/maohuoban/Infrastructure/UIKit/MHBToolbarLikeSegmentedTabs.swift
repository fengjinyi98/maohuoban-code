import SwiftUI
import UIKit

// MHBToolbarLikeSegmentedTabs 导航栏视觉分段控件
// 核心职责：
// - 使用原生 UISegmentedControl 保留系统分段控件视觉
// - 通过 UIKit 滚动容器支持超出可视区域的 tabs
// - 为导航栏与内容流复用同一套布局行为
struct MHBToolbarLikeSegmentedTabs<Selection: Hashable>: UIViewRepresentable {
    let items: [Item]
    @Binding var selection: Selection
    let segmentWidth: CGFloat
    let height: CGFloat
    let selectedSegmentTintColor: UIColor?
    let normalTitleColor: UIColor
    let selectedTitleColor: UIColor
    let scrollingSelectedTitleColor: UIColor?
    let accessibilityIdentifier: String

    init(
        items: [Item],
        selection: Binding<Selection>,
        segmentWidth: CGFloat = 64,
        height: CGFloat = 44,
        selectedSegmentTintColor: UIColor? = nil,
        normalTitleColor: UIColor = .label,
        selectedTitleColor: UIColor = .label,
        scrollingSelectedTitleColor: UIColor? = nil,
        accessibilityIdentifier: String
    ) {
        self.items = items
        self._selection = selection
        self.segmentWidth = segmentWidth
        self.height = height
        self.selectedSegmentTintColor = selectedSegmentTintColor
        self.normalTitleColor = normalTitleColor
        self.selectedTitleColor = selectedTitleColor
        self.scrollingSelectedTitleColor = scrollingSelectedTitleColor
        self.accessibilityIdentifier = accessibilityIdentifier
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> MHBToolbarLikeSegmentedTabsContainer {
        let container = MHBToolbarLikeSegmentedTabsContainer()
        let control = container.segmentedControl
        control.accessibilityIdentifier = accessibilityIdentifier
        control.isMomentary = false
        control.backgroundColor = .clear
        control.setContentHuggingPriority(.required, for: .horizontal)
        control.setContentCompressionResistancePriority(.required, for: .horizontal)
        control.setContentHuggingPriority(.required, for: .vertical)
        control.setContentCompressionResistancePriority(.required, for: .vertical)
        control.addTarget(
            context.coordinator,
            action: #selector(Coordinator.selectionDidChange(_:)),
            for: .valueChanged
        )
        context.coordinator.configure(container)
        return container
    }

    func updateUIView(_ uiView: MHBToolbarLikeSegmentedTabsContainer, context: Context) {
        context.coordinator.parent = self
        uiView.accessibilityIdentifier = accessibilityIdentifier
        context.coordinator.configure(uiView)
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: MHBToolbarLikeSegmentedTabsContainer,
        context: Context
    ) -> CGSize? {
        let visibleWidth = min(preferredWidth, proposal.width ?? preferredWidth)
        return CGSize(width: visibleWidth, height: height)
    }

    private var preferredWidth: CGFloat {
        CGFloat(items.count) * segmentWidth
    }
}

extension MHBToolbarLikeSegmentedTabs {
    // Item 导航栏视觉分段控件选项
    // 核心职责：
    // - 绑定业务选择值与展示标题
    // - 为 UIKit 分段控件提供稳定选项顺序
    struct Item: Identifiable, Hashable {
        let selection: Selection
        let title: String

        var id: Selection { selection }
    }
}

extension MHBToolbarLikeSegmentedTabs {
    // Coordinator 分段控件状态协调器
    // 核心职责：
    // - 同步 UIKit 选中态与 SwiftUI Binding
    // - 协调横向滚动与选中项可见状态
    final class Coordinator: NSObject {
        var parent: MHBToolbarLikeSegmentedTabs

        init(parent: MHBToolbarLikeSegmentedTabs) {
            self.parent = parent
        }

        func configure(_ container: MHBToolbarLikeSegmentedTabsContainer) {
            let control = container.segmentedControl
            container.updateContentLayout(
                preferredContentWidth: parent.preferredWidth,
                preferredHeight: parent.height,
                segmentWidth: parent.segmentWidth
            )
            container.onScrollInteractionStateChange = { [weak self, weak control] isActive in
                guard let self, let control else {
                    return
                }

                self.applyAppearance(to: control, isScrollInteractionActive: isActive)
            }
            reconcileSegments(in: control)
            applyAppearance(to: control, isScrollInteractionActive: container.isScrollInteractionActive)
            applyLayout(to: control)
            applySelection(to: control)
            container.scrollSelectedSegmentToVisible(animated: false)
        }

        @objc
        func selectionDidChange(_ sender: UISegmentedControl) {
            let selectedIndex = sender.selectedSegmentIndex
            guard parent.items.indices.contains(selectedIndex) else {
                return
            }

            let item = parent.items[selectedIndex]
            if let container = (sender as? MHBToolbarLikeSegmentedControl)?.mhb_tabsContainer {
                container.scrollSelectedSegmentToVisible(animated: true)
            }
            parent.selection = item.selection
        }

        private func reconcileSegments(in control: UISegmentedControl) {
            while control.numberOfSegments > parent.items.count {
                control.removeSegment(at: control.numberOfSegments - 1, animated: false)
            }

            for (index, item) in parent.items.enumerated() {
                if index >= control.numberOfSegments {
                    control.insertSegment(withTitle: item.title, at: index, animated: false)
                } else if control.titleForSegment(at: index) != item.title {
                    control.setTitle(item.title, forSegmentAt: index)
                }
            }
        }

        private func applyAppearance(
            to control: UISegmentedControl,
            isScrollInteractionActive: Bool
        ) {
            let selectedTitleColor = isScrollInteractionActive
                ? parent.scrollingSelectedTitleColor ?? parent.selectedTitleColor
                : parent.selectedTitleColor
            let normalAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 17, weight: .semibold),
                .foregroundColor: parent.normalTitleColor
            ]
            let selectedAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 17, weight: .semibold),
                .foregroundColor: selectedTitleColor
            ]
            control.selectedSegmentTintColor = parent.selectedSegmentTintColor
            control.setTitleTextAttributes(normalAttributes, for: .normal)
            control.setTitleTextAttributes(selectedAttributes, for: .selected)
            control.setTitleTextAttributes(selectedAttributes, for: .highlighted)
            control.setTitleTextAttributes(selectedAttributes, for: [.selected, .highlighted])
            control.setNeedsLayout()
            control.setNeedsDisplay()
        }

        private func applyLayout(to control: UISegmentedControl) {
            control.apportionsSegmentWidthsByContent = false
            for index in 0..<control.numberOfSegments {
                control.setWidth(parent.segmentWidth, forSegmentAt: index)
            }
        }

        private func applySelection(to control: UISegmentedControl) {
            guard let selectedIndex = parent.items.firstIndex(where: { $0.selection == parent.selection }) else {
                control.selectedSegmentIndex = UISegmentedControl.noSegment
                return
            }

            control.selectedSegmentIndex = selectedIndex
        }
    }
}

// MHBToolbarLikeSegmentedTabsContainer 分段控件滚动容器
// 核心职责：
// - 承载超出可视宽度的 UISegmentedControl
// - 在选中项变化时将对应 segment 滚动到可见区域
final class MHBToolbarLikeSegmentedTabsContainer: UIView, UIScrollViewDelegate {
    let scrollView = UIScrollView()
    let segmentedControl = MHBToolbarLikeSegmentedControl()

    var onScrollInteractionStateChange: ((Bool) -> Void)?
    private(set) var isScrollInteractionActive = false

    private var preferredContentWidth: CGFloat = 0
    private var preferredHeight: CGFloat = 0
    private var segmentWidth: CGFloat = 0
    private var shouldScrollSelectionAfterLayout = false

    override init(frame: CGRect) {
        super.init(frame: frame)

        isOpaque = false
        backgroundColor = .clear
        clipsToBounds = true

        scrollView.backgroundColor = .clear
        scrollView.clipsToBounds = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = false
        scrollView.alwaysBounceVertical = false
        scrollView.delaysContentTouches = false
        scrollView.delegate = self

        segmentedControl.mhb_tabsContainer = self

        addSubview(scrollView)
        scrollView.addSubview(segmentedControl)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let capsuleRadius = bounds.height / 2
        let visibleContentWidth = max(preferredContentWidth, bounds.width)
        let segmentedControlX = max(0, (visibleContentWidth - preferredContentWidth) / 2)

        applyCapsuleClipping(radius: capsuleRadius)

        scrollView.frame = bounds
        scrollView.contentSize = CGSize(
            width: visibleContentWidth,
            height: max(bounds.height, preferredHeight)
        )
        segmentedControl.frame = CGRect(
            x: segmentedControlX,
            y: max(0, (bounds.height - preferredHeight) / 2),
            width: preferredContentWidth,
            height: preferredHeight
        )
        clampContentOffsetIfNeeded()

        if shouldScrollSelectionAfterLayout {
            shouldScrollSelectionAfterLayout = false
            scrollSelectedSegmentToVisible(animated: false)
        }
    }

    func updateContentLayout(
        preferredContentWidth: CGFloat,
        preferredHeight: CGFloat,
        segmentWidth: CGFloat
    ) {
        self.preferredContentWidth = preferredContentWidth
        self.preferredHeight = preferredHeight
        self.segmentWidth = segmentWidth
        setNeedsLayout()
    }

    func scrollSelectedSegmentToVisible(animated: Bool) {
        let selectedIndex = segmentedControl.selectedSegmentIndex
        guard selectedIndex != UISegmentedControl.noSegment,
              selectedIndex >= 0,
              segmentWidth > 0,
              bounds.width > 0
        else {
            shouldScrollSelectionAfterLayout = true
            return
        }

        layoutIfNeeded()

        let segmentFrame = CGRect(
            x: segmentedControl.frame.minX + CGFloat(selectedIndex) * segmentWidth,
            y: 0,
            width: segmentWidth,
            height: max(bounds.height, preferredHeight)
        )
        let maxOffsetX = max(0, scrollView.contentSize.width - scrollView.bounds.width)
        let centeredOffsetX = segmentFrame.midX - scrollView.bounds.width / 2
        let targetOffsetX = min(max(0, centeredOffsetX), maxOffsetX)
        let previousOffset = scrollView.contentOffset
        let shouldAnimateScroll = animated && !targetOffsetX.mhb_isApproximatelyEqual(to: previousOffset.x)
        if shouldAnimateScroll {
            updateScrollInteractionActive(true)
        }
        scrollView.setContentOffset(
            CGPoint(x: targetOffsetX, y: previousOffset.y),
            animated: animated
        )
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        updateScrollInteractionActive(true)
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            updateScrollInteractionActive(false)
        }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        updateScrollInteractionActive(false)
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        updateScrollInteractionActive(false)
    }

    private func clampContentOffsetIfNeeded() {
        let maxOffsetX = max(0, scrollView.contentSize.width - scrollView.bounds.width)
        let clampedOffsetX = min(max(0, scrollView.contentOffset.x), maxOffsetX)
        guard !clampedOffsetX.mhb_isApproximatelyEqual(to: scrollView.contentOffset.x) else {
            return
        }

        scrollView.contentOffset.x = clampedOffsetX
    }

    private func updateScrollInteractionActive(_ isActive: Bool) {
        guard isScrollInteractionActive != isActive else {
            return
        }

        isScrollInteractionActive = isActive
        onScrollInteractionStateChange?(isActive)
    }

    private func applyCapsuleClipping(radius: CGFloat) {
        layer.cornerRadius = radius
        layer.cornerCurve = .continuous
        layer.masksToBounds = true

        scrollView.layer.cornerRadius = radius
        scrollView.layer.cornerCurve = .continuous
        scrollView.layer.masksToBounds = true
    }
}

// MHBToolbarLikeSegmentedControl 分段控件容器引用子类
// 核心职责：
// - 保留 UISegmentedControl 原生绘制与交互
// - 让 valueChanged 回调能访问外层滚动容器
final class MHBToolbarLikeSegmentedControl: UISegmentedControl {
    weak var mhb_tabsContainer: MHBToolbarLikeSegmentedTabsContainer?
}
