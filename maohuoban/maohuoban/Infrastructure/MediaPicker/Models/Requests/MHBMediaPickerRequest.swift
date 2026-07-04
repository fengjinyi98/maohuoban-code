import Foundation

// MHBMediaPickerRequest 媒体选择请求
// 核心职责：
// - 统一描述媒体选择器的选择数量和类型约束
// - 为头像、背景和后续 UGC 发布流程提供共用入口
// - 支持用 PhotoKit 本机标识做同设备禁选提示
struct MHBMediaPickerRequest: Hashable {
    let maxSelectionCount: Int
    let filter: MHBMediaPickerFilter
    let autoConfirmSingleSelection: Bool
    let disabledLocalIdentifiers: Set<String>
    let showsCameraEntry: Bool

    static let singleImage = MHBMediaPickerRequest(
        maxSelectionCount: 1,
        filter: .images,
        autoConfirmSingleSelection: true
    )

    static let singleVideo = MHBMediaPickerRequest(
        maxSelectionCount: 1,
        filter: .videos,
        autoConfirmSingleSelection: true
    )

    static let singleVideoOrLivePhoto = MHBMediaPickerRequest(
        maxSelectionCount: 1,
        filter: .videosAndLivePhotos,
        autoConfirmSingleSelection: true
    )

    init(
        maxSelectionCount: Int,
        filter: MHBMediaPickerFilter,
        autoConfirmSingleSelection: Bool = false,
        disabledLocalIdentifiers: Set<String> = [],
        showsCameraEntry: Bool = false
    ) {
        self.maxSelectionCount = max(maxSelectionCount, 1)
        self.filter = filter
        self.autoConfirmSingleSelection = autoConfirmSingleSelection
        self.disabledLocalIdentifiers = disabledLocalIdentifiers
        self.showsCameraEntry = showsCameraEntry
    }
}
