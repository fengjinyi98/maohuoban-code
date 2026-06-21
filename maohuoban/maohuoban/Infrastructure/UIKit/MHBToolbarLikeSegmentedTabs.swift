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
    let accessibilityIdentifier: String
    let debugContext: String

    init(
        items: [Item],
        selection: Binding<Selection>,
        segmentWidth: CGFloat = 64,
        height: CGFloat = 44,
        accessibilityIdentifier: String,
        debugContext: String
    ) {
        self.items = items
        self._selection = selection
        self.segmentWidth = segmentWidth
        self.height = height
        self.accessibilityIdentifier = accessibilityIdentifier
        self.debugContext = debugContext
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> MHBToolbarLikeSegmentedTabsContainer {
        let container = MHBToolbarLikeSegmentedTabsContainer()
        let control = container.segmentedControl
        control.mhb_debugContext = debugContext
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
        print("[DEBUG:TabsBridge] make context=\(debugContext) items=\(items.map(\.title)) selected=\(String(describing: selection)) width=\(preferredWidth)")
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
        let size = CGSize(width: visibleWidth, height: height)
        context.coordinator.logSizeThatFits(
            proposal: proposal,
            intrinsicSize: uiView.segmentedControl.intrinsicContentSize,
            returnedSize: size,
            bounds: uiView.bounds
        )
        return size
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
    // - 输出本轮实验所需的临时布局诊断日志
    final class Coordinator: NSObject {
        var parent: MHBToolbarLikeSegmentedTabs
        private var lastUpdateSignature = ""
        private var lastSizeSignature = ""

        init(parent: MHBToolbarLikeSegmentedTabs) {
            self.parent = parent
        }

        func configure(_ container: MHBToolbarLikeSegmentedTabsContainer) {
            let control = container.segmentedControl
            container.mhb_debugContext = parent.debugContext
            container.updateContentLayout(
                preferredContentWidth: parent.preferredWidth,
                preferredHeight: parent.height,
                segmentWidth: parent.segmentWidth
            )
            reconcileSegments(in: control)
            applyAppearance(to: control)
            applyLayout(to: control)
            applySelection(to: control)
            container.scrollSelectedSegmentToVisible(animated: false)
            logUpdate(container)
        }

        @objc
        func selectionDidChange(_ sender: UISegmentedControl) {
            let selectedIndex = sender.selectedSegmentIndex
            guard parent.items.indices.contains(selectedIndex) else {
                print("[DEBUG:TabsBridge] valueChanged context=\(parent.debugContext) invalidIndex=\(selectedIndex)")
                return
            }

            let item = parent.items[selectedIndex]
            print("[DEBUG:TabsBridge] valueChanged context=\(parent.debugContext) index=\(selectedIndex) title=\(item.title) value=\(String(describing: item.selection))")
            if let container = (sender as? MHBToolbarLikeSegmentedControl)?.mhb_tabsContainer {
                container.scrollSelectedSegmentToVisible(animated: true)
            }
            parent.selection = item.selection
        }

        func logSizeThatFits(
            proposal: ProposedViewSize,
            intrinsicSize: CGSize,
            returnedSize: CGSize,
            bounds: CGRect
        ) {
            let signature = [
                "context=\(parent.debugContext)",
                "proposal=\(format(proposal))",
                "intrinsic=\(format(intrinsicSize))",
                "returned=\(format(returnedSize))",
                "bounds=\(format(bounds))"
            ].joined(separator: " ")

            guard signature != lastSizeSignature else {
                return
            }

            lastSizeSignature = signature
            print("[DEBUG:TabsBridge] sizeThatFits \(signature)")
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

        private func applyAppearance(to control: UISegmentedControl) {
            let normalAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 17, weight: .semibold),
                .foregroundColor: UIColor.label
            ]
            let selectedAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 17, weight: .semibold),
                .foregroundColor: UIColor.label
            ]
            control.setTitleTextAttributes(normalAttributes, for: .normal)
            control.setTitleTextAttributes(selectedAttributes, for: .selected)
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

        private func logUpdate(_ container: MHBToolbarLikeSegmentedTabsContainer) {
            let control = container.segmentedControl
            let signature = [
                "context=\(parent.debugContext)",
                "segments=\(control.numberOfSegments)",
                "selectedIndex=\(control.selectedSegmentIndex)",
                "segmentWidth=\(format(parent.segmentWidth))",
                "preferredWidth=\(format(parent.preferredWidth))",
                "height=\(format(parent.height))",
                "viewport=\(format(container.bounds.size))",
                "contentOffset=\(format(container.scrollView.contentOffset))",
                "bounds=\(format(control.bounds))",
                "intrinsic=\(format(control.intrinsicContentSize))"
            ].joined(separator: " ")

            guard signature != lastUpdateSignature else {
                return
            }

            lastUpdateSignature = signature
            print("[DEBUG:TabsBridge] update \(signature)")
        }

        private func format(_ proposal: ProposedViewSize) -> String {
            "w:\(format(proposal.width)) h:\(format(proposal.height))"
        }

        private func format(_ size: CGSize) -> String {
            "w:\(format(size.width)) h:\(format(size.height))"
        }

        private func format(_ rect: CGRect) -> String {
            "x:\(format(rect.origin.x)) y:\(format(rect.origin.y)) w:\(format(rect.width)) h:\(format(rect.height))"
        }

        private func format(_ point: CGPoint) -> String {
            "x:\(format(point.x)) y:\(format(point.y))"
        }

        private func format(_ value: CGFloat?) -> String {
            guard let value else {
                return "nil"
            }

            return format(value)
        }

        private func format(_ value: CGFloat) -> String {
            String(format: "%.1f", value)
        }
    }
}

// MHBToolbarLikeSegmentedTabsContainer 分段控件滚动容器
// 核心职责：
// - 承载超出可视宽度的 UISegmentedControl
// - 在选中项变化时将对应 segment 滚动到可见区域
final class MHBToolbarLikeSegmentedTabsContainer: UIView {
    let scrollView = UIScrollView()
    let segmentedControl = MHBToolbarLikeSegmentedControl()

    var mhb_debugContext = ""

    private var preferredContentWidth: CGFloat = 0
    private var preferredHeight: CGFloat = 0
    private var segmentWidth: CGFloat = 0
    private var shouldScrollSelectionAfterLayout = false
    private var lastLayoutSignature = ""
    private var lastScrollSignature = ""

    override init(frame: CGRect) {
        super.init(frame: frame)

        isOpaque = false
        backgroundColor = .clear

        scrollView.backgroundColor = .clear
        scrollView.clipsToBounds = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = false
        scrollView.alwaysBounceVertical = false

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

        scrollView.frame = bounds
        scrollView.contentSize = CGSize(
            width: preferredContentWidth,
            height: max(bounds.height, preferredHeight)
        )
        segmentedControl.frame = CGRect(
            x: 0,
            y: max(0, (bounds.height - preferredHeight) / 2),
            width: preferredContentWidth,
            height: preferredHeight
        )
        clampContentOffsetIfNeeded()
        logLayoutIfNeeded()

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
            x: CGFloat(selectedIndex) * segmentWidth,
            y: 0,
            width: segmentWidth,
            height: max(bounds.height, preferredHeight)
        )
        let targetFrame = segmentFrame.insetBy(dx: -MHBToolbarLikeSegmentedTabsLayout.autoScrollMargin, dy: 0)
        let wasVisible = scrollView.bounds.contains(segmentFrame)
        let previousOffset = scrollView.contentOffset
        scrollView.scrollRectToVisible(targetFrame, animated: animated)
        logSelectionScrollIfNeeded(
            selectedIndex: selectedIndex,
            animated: animated,
            wasVisible: wasVisible,
            previousOffset: previousOffset,
            targetFrame: targetFrame
        )
    }

    private func clampContentOffsetIfNeeded() {
        let maxOffsetX = max(0, scrollView.contentSize.width - scrollView.bounds.width)
        let clampedOffsetX = min(max(0, scrollView.contentOffset.x), maxOffsetX)
        guard !clampedOffsetX.mhb_isApproximatelyEqual(to: scrollView.contentOffset.x) else {
            return
        }

        scrollView.contentOffset.x = clampedOffsetX
    }

    private func logLayoutIfNeeded() {
        let signature = [
            "context=\(mhb_debugContext)",
            "viewport=w:\(bounds.width.mhb_formattedTabsBridgeValue) h:\(bounds.height.mhb_formattedTabsBridgeValue)",
            "content=w:\(preferredContentWidth.mhb_formattedTabsBridgeValue) h:\(preferredHeight.mhb_formattedTabsBridgeValue)",
            "offset=x:\(scrollView.contentOffset.x.mhb_formattedTabsBridgeValue)",
            "selectedIndex=\(segmentedControl.selectedSegmentIndex)"
        ].joined(separator: " ")

        guard signature != lastLayoutSignature else {
            return
        }

        lastLayoutSignature = signature
        print("[DEBUG:TabsBridge] scrollLayout \(signature)")
    }

    private func logSelectionScrollIfNeeded(
        selectedIndex: Int,
        animated: Bool,
        wasVisible: Bool,
        previousOffset: CGPoint,
        targetFrame: CGRect
    ) {
        let signature = [
            "context=\(mhb_debugContext)",
            "selectedIndex=\(selectedIndex)",
            "animated=\(animated)",
            "wasVisible=\(wasVisible)",
            "from=x:\(previousOffset.x.mhb_formattedTabsBridgeValue)",
            "to=x:\(scrollView.contentOffset.x.mhb_formattedTabsBridgeValue)",
            "target=x:\(targetFrame.origin.x.mhb_formattedTabsBridgeValue) w:\(targetFrame.width.mhb_formattedTabsBridgeValue)"
        ].joined(separator: " ")

        guard signature != lastScrollSignature else {
            return
        }

        lastScrollSignature = signature
        print("[DEBUG:TabsBridge] autoScroll \(signature)")
    }
}

// MHBToolbarLikeSegmentedTabsLayout 分段控件滚动布局参数
// 核心职责：
// - 统一 UIKit tabs 自动滚动的可视边距
// - 避免选中 segment 紧贴滚动容器边缘
private enum MHBToolbarLikeSegmentedTabsLayout {
    static let autoScrollMargin: CGFloat = 12
}

// MHBToolbarLikeSegmentedControl 分段控件布局诊断子类
// 核心职责：
// - 保留 UISegmentedControl 原生绘制与交互
// - 在布局结果变化时输出临时诊断日志
final class MHBToolbarLikeSegmentedControl: UISegmentedControl {
    var mhb_debugContext = ""
    weak var mhb_tabsContainer: MHBToolbarLikeSegmentedTabsContainer?
    private var lastLoggedBounds = CGRect.null

    override func layoutSubviews() {
        super.layoutSubviews()

        guard !lastLoggedBounds.mhb_isApproximatelyEqual(to: bounds) else {
            return
        }

        lastLoggedBounds = bounds
        print("[DEBUG:TabsBridge] layout context=\(mhb_debugContext) bounds=x:\(bounds.origin.x.mhb_formattedTabsBridgeValue) y:\(bounds.origin.y.mhb_formattedTabsBridgeValue) w:\(bounds.width.mhb_formattedTabsBridgeValue) h:\(bounds.height.mhb_formattedTabsBridgeValue) intrinsic=w:\(intrinsicContentSize.width.mhb_formattedTabsBridgeValue) h:\(intrinsicContentSize.height.mhb_formattedTabsBridgeValue)")
    }
}

private extension CGRect {
    func mhb_isApproximatelyEqual(to other: CGRect) -> Bool {
        origin.x.mhb_isApproximatelyEqual(to: other.origin.x) &&
            origin.y.mhb_isApproximatelyEqual(to: other.origin.y) &&
            width.mhb_isApproximatelyEqual(to: other.width) &&
            height.mhb_isApproximatelyEqual(to: other.height)
    }
}

private extension CGFloat {
    var mhb_formattedTabsBridgeValue: String {
        String(format: "%.1f", self)
    }
}
