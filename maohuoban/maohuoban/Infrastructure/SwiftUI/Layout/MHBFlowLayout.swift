import SwiftUI

// MHBFlowLayout 左对齐流式布局
// 核心职责：
// - 按子视图自身尺寸从左到右排布
// - 在可用宽度不足时自动换行
struct MHBFlowLayout: Layout {
    let horizontalSpacing: CGFloat
    let verticalSpacing: CGFloat

    init(
        horizontalSpacing: CGFloat,
        verticalSpacing: CGFloat
    ) {
        self.horizontalSpacing = horizontalSpacing
        self.verticalSpacing = verticalSpacing
    }

    nonisolated func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) -> CGSize {
        let rows = rows(
            maxWidth: resolvedMaxWidth(proposal.width),
            subviews: subviews
        )

        return CGSize(
            width: resolvedOutputWidth(
                proposedWidth: proposal.width,
                rows: rows
            ),
            height: rows.last.map { $0.originY + $0.height } ?? 0
        )
    }

    nonisolated func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) {
        for row in rows(maxWidth: bounds.width, subviews: subviews) {
            for item in row.items {
                subviews[item.index].place(
                    at: CGPoint(
                        x: bounds.minX + item.originX,
                        y: bounds.minY + row.originY
                    ),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(
                        width: item.size.width,
                        height: item.size.height
                    )
                )
            }
        }
    }

    nonisolated private func rows(
        maxWidth: CGFloat,
        subviews: Subviews
    ) -> [MHBFlowLayoutRow] {
        var rows: [MHBFlowLayoutRow] = []
        var currentItems: [MHBFlowLayoutItem] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var currentHeight: CGFloat = 0
        let effectiveMaxWidth = max(maxWidth, 1)

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let itemX = currentItems.isEmpty ? 0 : currentX + horizontalSpacing
            let shouldWrap = !currentItems.isEmpty && itemX + size.width > effectiveMaxWidth

            if shouldWrap {
                rows.append(
                    MHBFlowLayoutRow(
                        items: currentItems,
                        originY: currentY,
                        height: currentHeight
                    )
                )
                currentY += currentHeight + verticalSpacing
                currentItems = []
                currentX = 0
                currentHeight = 0
            }

            let resolvedX = currentItems.isEmpty ? 0 : currentX + horizontalSpacing
            currentItems.append(
                MHBFlowLayoutItem(
                    index: index,
                    originX: resolvedX,
                    size: size
                )
            )
            currentX = resolvedX + size.width
            currentHeight = max(currentHeight, size.height)
        }

        if !currentItems.isEmpty {
            rows.append(
                MHBFlowLayoutRow(
                    items: currentItems,
                    originY: currentY,
                    height: currentHeight
                )
            )
        }

        return rows
    }

    nonisolated private func resolvedMaxWidth(_ proposedWidth: CGFloat?) -> CGFloat {
        guard let proposedWidth,
              proposedWidth.isFinite,
              proposedWidth > 0
        else {
            return .greatestFiniteMagnitude
        }

        return proposedWidth
    }

    nonisolated private func resolvedOutputWidth(
        proposedWidth: CGFloat?,
        rows: [MHBFlowLayoutRow]
    ) -> CGFloat {
        guard let proposedWidth,
              proposedWidth.isFinite,
              proposedWidth > 0
        else {
            return rows.map { row in row.width }.max() ?? 0
        }

        return proposedWidth
    }
}

// MHBFlowLayoutRow 流式布局行
// 核心职责：
// - 记录一行内的子视图位置
// - 提供该行宽高供整体尺寸计算使用
private struct MHBFlowLayoutRow {
    let items: [MHBFlowLayoutItem]
    let originY: CGFloat
    let height: CGFloat

    nonisolated var width: CGFloat {
        items.last.map { $0.originX + $0.size.width } ?? 0
    }
}

// MHBFlowLayoutItem 流式布局元素
// 核心职责：
// - 记录单个子视图的索引、横向位置和尺寸
// - 为 SwiftUI Layout 放置阶段提供稳定输入
private struct MHBFlowLayoutItem {
    let index: Int
    let originX: CGFloat
    let size: CGSize
}
