import Foundation

// MHBPickedVideo 已选择视频资源
// 核心职责：
// - 承载从系统相册复制到本地临时目录的视频 URL
// - 为背景视频和后续 UGC 视频发布提供统一结果模型
struct MHBPickedVideo: Identifiable, Hashable {
    let id = UUID()
    let url: URL
}
