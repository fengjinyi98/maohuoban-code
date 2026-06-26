import SwiftUI

// MHBMediaPickerScreen 基础设施媒体选择器
// 核心职责：
// - 统一承接业务页面的图片、视频和 Live Photo 选择请求
// - 隐藏底层 PhotoKit 选择器实现，避免业务层直接使用系统选择器 API
struct MHBMediaPickerScreen: View {
    let title: String
    let request: MHBMediaPickerRequest
    let onComplete: (MHBMediaPickerResult) -> Void
    let onCancel: () -> Void

    init(
        title: String = "选择照片",
        request: MHBMediaPickerRequest = .singleImage,
        onComplete: @escaping (MHBMediaPickerResult) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.title = title
        self.request = request
        self.onComplete = onComplete
        self.onCancel = onCancel
    }

    var body: some View {
        MHBPhotoLibraryPickerScreen(
            title: title,
            request: request,
            onComplete: onComplete,
            onCancel: onCancel
        )
    }
}
