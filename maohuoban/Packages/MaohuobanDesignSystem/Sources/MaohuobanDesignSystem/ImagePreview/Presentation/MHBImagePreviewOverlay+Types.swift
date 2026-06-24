import CoreGraphics

// MHBImagePreviewDismissTarget 图片预览关闭目标
// 核心职责：
// - 承载关闭时回落到哪个 source 的解析结果
// - 为 Hero 回落动画提供目标 frame、圆角与图片尺寸
struct MHBImagePreviewDismissTarget {
    let targetFrame: CGRect
    let targetCornerRadius: CGFloat
    let mediaSize: CGSize
}

// MHBImagePreviewDragAxisLock 预览拖拽轴锁
// 核心职责：
// - 在用户开始下拉关闭后锁定为纵向拖拽
// - 阻断同一手势序列继续触发横向分页切图
enum MHBImagePreviewDragAxisLock {
    case undecided
    case horizontal
    case vertical
}
