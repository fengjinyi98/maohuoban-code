import SwiftUI
import MaohuobanDesignSystem

// HomeQuickFactOptionalPhotoSection 快捷记录可选照片区
// 核心职责：
// - 为喂食等记录提供可选照片入口
// - 复用事件附件网格展示即时上传结果
struct HomeQuickFactOptionalPhotoSection: View {
    let title: LocalizedStringResource
    let attachments: [PetEventAttachmentDraft]
    let canAddMore: Bool
    let onAdd: () -> Void
    let onRemove: (UUID) -> Void
    let onRetry: (UUID) -> Void

    var body: some View {
        HomeQuickFactSheetSection(title: title) {
            PetEventAttachmentInputGrid(
                attachments: attachments,
                canAddMore: canAddMore,
                onAdd: onAdd,
                onRemove: onRemove,
                onRetry: onRetry
            )
        }
    }
}
