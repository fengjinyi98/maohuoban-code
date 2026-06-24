import UIKit

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
    private var segmentWidths: [CGFloat] = []
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

    @discardableResult
    func updateContentLayout(
        preferredContentWidth: CGFloat,
        preferredHeight: CGFloat,
        segmentWidths: [CGFloat]
    ) -> Bool {
        let layoutChanged = !preferredContentWidth.mhb_isApproximatelyEqual(to: self.preferredContentWidth) ||
            !preferredHeight.mhb_isApproximatelyEqual(to: self.preferredHeight) ||
            segmentWidths != self.segmentWidths

        self.preferredContentWidth = preferredContentWidth
        self.preferredHeight = preferredHeight
        self.segmentWidths = segmentWidths
        if layoutChanged {
            setNeedsLayout()
        }

        return layoutChanged
    }

    func scrollSelectedSegmentToVisible(animated: Bool) {
        let selectedIndex = segmentedControl.selectedSegmentIndex
        guard selectedIndex != UISegmentedControl.noSegment,
              selectedIndex >= 0,
              segmentWidths.indices.contains(selectedIndex),
              bounds.width > 0
        else {
            shouldScrollSelectionAfterLayout = true
            return
        }

        layoutIfNeeded()

        let segmentFrame = CGRect(
            x: segmentedControl.frame.minX + segmentWidths.prefix(selectedIndex).reduce(0, +),
            y: 0,
            width: segmentWidths[selectedIndex],
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
