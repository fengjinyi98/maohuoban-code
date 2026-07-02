import SwiftUI
import MaohuobanDesignSystem

// PetMediaUploadProgressOverlay 宠物媒体上传遮罩
// 核心职责：
// - 统一展示头像、背景等宠物媒体上传中的遮罩
// - 复用 PetMediaUploadStore 暴露的上传状态
struct PetMediaUploadProgressOverlay: View {
    let state: PetMediaUploadSlotState

    var body: some View {
        if case .uploading(let progress) = state {
            Color.black.opacity(0.38)
                .overlay {
                    if let progress {
                        ProgressView(value: progress)
                            .progressViewStyle(.circular)
                            .tint(.white)
                    } else {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                    }
                }
        }
    }
}
