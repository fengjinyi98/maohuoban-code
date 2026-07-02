import SwiftUI
import MaohuobanDesignSystem

// PetProfileEditNotesSection 编辑宠物备注资料区段
// 核心职责：
// - 展示性格标签和备注入口
// - 保持备注区段行样式与编辑页一致
struct PetProfileEditNotesSection: View {
    let personalityTags: [String]
    let noteText: String
    let isTagsExpanded: Bool
    let isNoteExpanded: Bool
    let onTags: () -> Void
    let onNote: () -> Void

    var body: some View {
        PetProfileEditSection {
            PetProfileEditRow(
                title: "性格标签",
                isAccessoryExpanded: isTagsExpanded,
                action: onTags
            ) {
                PetProfileEditTagFlow(tags: personalityTags)
            }

            PetProfileEditRow(
                title: "备注",
                showsSeparator: false,
                isAccessoryExpanded: isNoteExpanded,
                action: onNote
            ) {
                PetProfileEditValueText(value: noteText)
            }
        }
    }
}

// PetProfileEditDeleteSection 删除宠物档案入口区段
// 核心职责：
// - 承载删除宠物档案入口
// - 固定危险操作颜色与可访问性标识
struct PetProfileEditDeleteSection: View {
    let onDelete: () -> Void

    var body: some View {
        PetProfileEditSection {
            PetProfileEditRow(
                title: "删除宠物档案",
                showsSeparator: false,
                titleColor: MHBTheme.ColorToken.danger.color,
                action: onDelete
            ) {
                EmptyView()
            }
            .accessibilityIdentifier("pet.profileEdit.deleteEntry")
        }
    }
}
