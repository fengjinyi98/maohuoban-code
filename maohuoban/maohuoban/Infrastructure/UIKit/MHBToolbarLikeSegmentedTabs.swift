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
    let segmentWidths: [CGFloat]
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
        self.segmentWidths = Array(repeating: max(0, segmentWidth), count: items.count)
        self.height = height
        self.selectedSegmentTintColor = selectedSegmentTintColor
        self.normalTitleColor = normalTitleColor
        self.selectedTitleColor = selectedTitleColor
        self.scrollingSelectedTitleColor = scrollingSelectedTitleColor
        self.accessibilityIdentifier = accessibilityIdentifier
    }

    init(
        items: [Item],
        selection: Binding<Selection>,
        segmentWidths: [CGFloat],
        height: CGFloat = 44,
        selectedSegmentTintColor: UIColor? = nil,
        normalTitleColor: UIColor = .label,
        selectedTitleColor: UIColor = .label,
        scrollingSelectedTitleColor: UIColor? = nil,
        accessibilityIdentifier: String
    ) {
        self.items = items
        self._selection = selection
        self.segmentWidths = segmentWidths
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
        let visibleWidth = proposal.width ?? preferredWidth
        return CGSize(width: visibleWidth, height: height)
    }

    private var preferredWidth: CGFloat {
        resolvedSegmentWidths.reduce(0, +)
    }

    private var resolvedSegmentWidths: [CGFloat] {
        let fallbackWidth = max(0, segmentWidths.first ?? 64)
        guard segmentWidths.count == items.count else {
            return Array(repeating: fallbackWidth, count: items.count)
        }

        return segmentWidths.map { max(0, $0) }
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
            let layoutChanged = container.updateContentLayout(
                preferredContentWidth: parent.preferredWidth,
                preferredHeight: parent.height,
                segmentWidths: parent.resolvedSegmentWidths
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
            let selectionChanged = applySelection(to: control)
            if layoutChanged || selectionChanged {
                container.scrollSelectedSegmentToVisible(animated: false)
            }
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
            for index in 0..<control.numberOfSegments where parent.resolvedSegmentWidths.indices.contains(index) {
                control.setWidth(parent.resolvedSegmentWidths[index], forSegmentAt: index)
            }
        }

        private func applySelection(to control: UISegmentedControl) -> Bool {
            let previousIndex = control.selectedSegmentIndex
            guard let selectedIndex = parent.items.firstIndex(where: { $0.selection == parent.selection }) else {
                control.selectedSegmentIndex = UISegmentedControl.noSegment
                return previousIndex != UISegmentedControl.noSegment
            }

            control.selectedSegmentIndex = selectedIndex
            return previousIndex != selectedIndex
        }
    }
}
