import SwiftUI

// PetProfileEditSelectionOverlays 编辑页选择菜单覆盖层
// 核心职责：
// - 承载宠物类型、性别和绝育状态选择菜单
// - 保持外部点击关闭层和菜单 zIndex 顺序
struct PetProfileEditSelectionOverlays: View {
    let isSpeciesPresented: Bool
    let isSexPresented: Bool
    let isNeuterStatusPresented: Bool
    let containerWidth: CGFloat
    let speciesRowFrame: CGRect
    let sexRowFrame: CGRect
    let neuterStatusRowFrame: CGRect
    let speciesText: String
    let sexText: String
    let neuterStatusText: String
    let onDismiss: () -> Void
    let onSpeciesSelect: (String) -> Void
    let onSexSelect: (String) -> Void
    let onNeuterStatusSelect: (String) -> Void

    var body: some View {
        if isSpeciesPresented || isSexPresented || isNeuterStatusPresented {
            MHBOutsideTapDismissLayer(onDismiss: onDismiss)
                .zIndex(1)
        }

        PetProfileEditSelectionMenuOverlay(
            isPresented: isSpeciesPresented,
            containerWidth: containerWidth,
            rowFrame: speciesRowFrame,
            selectedValue: speciesText,
            options: ["狗狗", "猫咪", "其他"],
            onSelect: onSpeciesSelect
        )
        .zIndex(2)

        PetProfileEditSelectionMenuOverlay(
            isPresented: isSexPresented,
            containerWidth: containerWidth,
            rowFrame: sexRowFrame,
            selectedValue: sexText,
            options: ["公", "母"],
            onSelect: onSexSelect
        )
        .zIndex(2)

        PetProfileEditSelectionMenuOverlay(
            isPresented: isNeuterStatusPresented,
            containerWidth: containerWidth,
            rowFrame: neuterStatusRowFrame,
            selectedValue: neuterStatusText,
            options: ["已绝育", "未绝育"],
            onSelect: onNeuterStatusSelect
        )
        .zIndex(2)
    }
}
