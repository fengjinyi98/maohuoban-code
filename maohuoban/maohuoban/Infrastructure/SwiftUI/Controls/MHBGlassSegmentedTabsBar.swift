import SwiftUI
import UIKit

// MHBGlassSegmentedTabsBar Liquid Glass 分段 tabs 外壳
// 核心职责：
// - 统一承载 Liquid Glass 胶囊容器
// - 为业务页面提供可复用的 tabs 宽度策略
// - 将 SwiftUI 外观容器与 UIKit 分段控件滚动能力组合起来
struct MHBGlassSegmentedTabsBar<Selection: Hashable>: View {
    let items: [Item]
    @Binding var selection: Selection
    let widthStrategy: WidthStrategy
    let height: CGFloat
    let selectedSegmentTintColor: UIColor?
    let normalTitleColor: UIColor
    let selectedTitleColor: UIColor
    let scrollingSelectedTitleColor: UIColor?
    let accessibilityIdentifier: String

    init(
        items: [Item],
        selection: Binding<Selection>,
        widthStrategy: WidthStrategy = .fixed(64),
        height: CGFloat = 44,
        selectedSegmentTintColor: UIColor? = nil,
        normalTitleColor: UIColor = .label,
        selectedTitleColor: UIColor = .label,
        scrollingSelectedTitleColor: UIColor? = nil,
        accessibilityIdentifier: String
    ) {
        self.items = items
        self._selection = selection
        self.widthStrategy = widthStrategy
        self.height = height
        self.selectedSegmentTintColor = selectedSegmentTintColor
        self.normalTitleColor = normalTitleColor
        self.selectedTitleColor = selectedTitleColor
        self.scrollingSelectedTitleColor = scrollingSelectedTitleColor
        self.accessibilityIdentifier = accessibilityIdentifier
    }

    var body: some View {
        GeometryReader { proxy in
            let visibleWidth = max(0, proxy.size.width)
            let segmentWidths = widthStrategy.segmentWidths(
                for: items,
                visibleWidth: visibleWidth
            )

            ZStack {
                Color.clear
                    .frame(width: visibleWidth, height: height)
                    .glassEffect(.regular.interactive(), in: .capsule)
                    .allowsHitTesting(false)

                MHBToolbarLikeSegmentedTabs(
                    items: items.map { item in
                        MHBToolbarLikeSegmentedTabs<Selection>.Item(
                            selection: item.selection,
                            title: item.title
                        )
                    },
                    selection: $selection,
                    segmentWidths: segmentWidths,
                    height: height,
                    selectedSegmentTintColor: selectedSegmentTintColor,
                    normalTitleColor: normalTitleColor,
                    selectedTitleColor: selectedTitleColor,
                    scrollingSelectedTitleColor: scrollingSelectedTitleColor,
                    accessibilityIdentifier: accessibilityIdentifier
                )
                .frame(width: visibleWidth, height: height)
            }
            .frame(width: visibleWidth, height: height)
        }
        .frame(height: height)
    }
}

extension MHBGlassSegmentedTabsBar {
    // Item Liquid Glass tabs 选项
    // 核心职责：
    // - 绑定业务选择值与展示标题
    // - 为 SwiftUI 包装层提供稳定选项顺序
    struct Item: Identifiable, Hashable {
        let selection: Selection
        let title: String

        var id: Selection { selection }
    }
}

extension MHBGlassSegmentedTabsBar {
    // WidthStrategy tabs 宽度策略
    // 核心职责：
    // - 支持固定宽度、可视区均分和内容自适应
    // - 为 UIKit 分段控件生成每个 segment 的实际宽度
    enum WidthStrategy: Equatable {
        case fixed(CGFloat)
        case equalVisible
        case intrinsic(minimum: CGFloat, horizontalPadding: CGFloat)

        static var content: WidthStrategy {
            .intrinsic(
                minimum: MHBGlassSegmentedTabsBarMetrics.minimumContentSegmentWidth,
                horizontalPadding: MHBGlassSegmentedTabsBarMetrics.contentSegmentHorizontalPadding
            )
        }

        @MainActor
        func segmentWidths(
            for items: [Item],
            visibleWidth: CGFloat
        ) -> [CGFloat] {
            guard !items.isEmpty else {
                return []
            }

            switch self {
            case let .fixed(width):
                return Array(repeating: max(0, width), count: items.count)

            case .equalVisible:
                let width = max(0, visibleWidth) / CGFloat(items.count)
                return Array(repeating: width, count: items.count)

            case let .intrinsic(minimum, horizontalPadding):
                return items.map { item in
                    let titleWidth = (item.title as NSString).size(
                        withAttributes: [.font: MHBGlassSegmentedTabsBarMetrics.titleFont]
                    ).width
                    return max(minimum, ceil(titleWidth + horizontalPadding * 2))
                }
            }
        }
    }
}

// MHBGlassSegmentedTabsBarMetrics tabs 包装层布局参数
// 核心职责：
// - 统一内容宽度策略的测量字体和默认间距
// - 避免业务页面重复硬编码 UIKit tabs 测量参数
private enum MHBGlassSegmentedTabsBarMetrics {
    static let titleFont = UIFont.systemFont(ofSize: 17, weight: .semibold)
    static let minimumContentSegmentWidth: CGFloat = 64
    static let contentSegmentHorizontalPadding: CGFloat = 14
}
