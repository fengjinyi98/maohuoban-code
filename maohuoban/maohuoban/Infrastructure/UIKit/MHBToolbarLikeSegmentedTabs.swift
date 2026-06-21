import SwiftUI
import UIKit

// MHBToolbarLikeSegmentedTabs 导航栏视觉分段控件
// 核心职责：
// - 使用原生 UISegmentedControl 保留系统分段控件视觉
// - 通过 SwiftUI bridge 控制首选尺寸和每个 segment 宽度
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

    func makeUIView(context: Context) -> MHBToolbarLikeSegmentedControl {
        let control = MHBToolbarLikeSegmentedControl()
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
        context.coordinator.configure(control)
        print("[DEBUG:TabsBridge] make context=\(debugContext) items=\(items.map(\.title)) selected=\(String(describing: selection)) width=\(preferredWidth)")
        return control
    }

    func updateUIView(_ uiView: MHBToolbarLikeSegmentedControl, context: Context) {
        context.coordinator.parent = self
        uiView.mhb_debugContext = debugContext
        uiView.accessibilityIdentifier = accessibilityIdentifier
        context.coordinator.configure(uiView)
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: MHBToolbarLikeSegmentedControl,
        context: Context
    ) -> CGSize? {
        let size = CGSize(width: preferredWidth, height: height)
        context.coordinator.logSizeThatFits(
            proposal: proposal,
            intrinsicSize: uiView.intrinsicContentSize,
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

        func configure(_ control: UISegmentedControl) {
            reconcileSegments(in: control)
            applyAppearance(to: control)
            applyLayout(to: control)
            applySelection(to: control)
            logUpdate(control)
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

        private func logUpdate(_ control: UISegmentedControl) {
            let signature = [
                "context=\(parent.debugContext)",
                "segments=\(control.numberOfSegments)",
                "selectedIndex=\(control.selectedSegmentIndex)",
                "segmentWidth=\(format(parent.segmentWidth))",
                "preferredWidth=\(format(parent.preferredWidth))",
                "height=\(format(parent.height))",
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

// MHBToolbarLikeSegmentedControl 分段控件布局诊断子类
// 核心职责：
// - 保留 UISegmentedControl 原生绘制与交互
// - 在布局结果变化时输出临时诊断日志
final class MHBToolbarLikeSegmentedControl: UISegmentedControl {
    var mhb_debugContext = ""
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
