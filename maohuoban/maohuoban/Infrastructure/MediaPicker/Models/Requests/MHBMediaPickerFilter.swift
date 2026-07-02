import Foundation

// MHBMediaPickerFilter 媒体选择过滤条件
// 核心职责：
// - 描述业务发起媒体选择时允许选择的资源类型
// - 为 PhotoKit 基础设施选择器提供稳定过滤入口
enum MHBMediaPickerFilter: Hashable {
    case images
    case videos
    case videosAndLivePhotos
    case all
}
