import SwiftUI
import MaohuobanDesignSystem

// PetEventAttachmentInputGrid 事件附件输入网格
// 核心职责：
// - 统一喂食与异常记录的附件缩略图排列
// - 承载添加、删除和重试等用户事件入口
struct PetEventAttachmentInputGrid: View {
    let attachments: [PetEventAttachmentDraft]
    let canAddMore: Bool
    let onAdd: () -> Void
    let onRemove: (UUID) -> Void
    let onRetry: (UUID) -> Void

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s2) {
            ForEach(attachments) { attachment in
                PetEventAttachmentThumbnail(
                    attachment: attachment,
                    onRemove: {
                        onRemove(attachment.id)
                    },
                    onRetry: {
                        onRetry(attachment.id)
                    }
                )
            }

            if canAddMore {
                PetEventAttachmentAddButton(action: onAdd)
            }
        }
    }
}
