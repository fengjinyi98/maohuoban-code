import CoreGraphics

// MHBPhotoGridScrollDateSnapshot 照片网格滚动日期快照
// 核心职责：
// - 表达当前滚动位置对应的日期文案
// - 提供浮层垂直定位所需的滚动进度
struct MHBPhotoGridScrollDateSnapshot: Equatable {
    let title: String
    let progress: CGFloat
}
