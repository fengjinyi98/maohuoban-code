import SwiftUI
import MaohuobanDesignSystem

// PetAbnormalRecordTopChrome 异常记录顶部导航控件
// 核心职责：
// - 在系统导航栏视觉位置展示返回、标题和宠物切换
// - 使用自绘 chrome 承载带 Liquid Glass 的宠物切换基础设施
struct PetAbnormalRecordTopChrome: View {
    let selectedItem: MHBPetSwitcherItem?
    let items: [MHBPetSwitcherItem]
    let isDisabled: Bool
    let onBack: () -> Void
    let onSelect: (String) -> Void

    var body: some View {
        GlassEffectContainer(spacing: MHBTheme.Spacing.s3) {
            ZStack {
                HStack(spacing: MHBTheme.Spacing.s3) {
                    PetAbnormalRecordBackButton(onBack: onBack)
                    Spacer(minLength: MHBTheme.Spacing.s3)
                }

                Text("异常")
                    .font(MHBTheme.Typography.headline.weight(.semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                    .frame(height: 48)
                    .accessibilityAddTraits(.isHeader)

                HStack {
                    Spacer(minLength: MHBTheme.Spacing.s3)

                    PetAbnormalRecordPetSwitcherMenu(
                        selectedItem: selectedItem,
                        items: items,
                        isDisabled: isDisabled,
                        onSelect: onSelect
                    )
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// PetAbnormalRecordBackButton 异常记录返回按钮
// 核心职责：
// - 承载顶部左侧返回动作
// - 保持自绘顶部栏 Liquid Glass 圆形反馈
private struct PetAbnormalRecordBackButton: View {
    let onBack: () -> Void

    var body: some View {
        Button(action: onBack) {
            Image(systemName: "chevron.left")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .frame(width: 48, height: 48)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel("返回")
        .accessibilityIdentifier("pet.abnormalRecord.backButton")
    }
}

// PetAbnormalRecordPetSwitcherMenu 异常记录宠物切换菜单
// 核心职责：
// - 在自绘顶部栏右侧展示当前宠物
// - 使用原生 Menu 承载多宠切换动作
private struct PetAbnormalRecordPetSwitcherMenu: View {
    let selectedItem: MHBPetSwitcherItem?
    let items: [MHBPetSwitcherItem]
    let isDisabled: Bool
    let onSelect: (String) -> Void

    var body: some View {
        Menu {
            ForEach(items) { item in
                Button {
                    onSelect(item.id)
                } label: {
                    Label(item.name, systemImage: item.isSelected ? "checkmark.circle.fill" : "circle")
                }
            }
        } label: {
            MHBPetSwitcherCapsule(
                item: selectedItem,
                isDisabled: false
            )
        }
        .disabled(isDisabled)
        .accessibilityIdentifier("pet.abnormalRecord.petSwitcherButton")
    }
}

extension MHBPetSwitcherItem {
    init(abnormalRecordPet pet: PetRecordSwitchPet, isSelected: Bool) {
        self.init(
            id: pet.id,
            name: pet.name ?? "未命名宠物",
            subtitle: pet.breed,
            avatarURLString: pet.avatarURL,
            species: MHBPetSwitcherSpecies(abnormalRecordSpecies: pet.species),
            sex: MHBPetSwitcherSex(abnormalRecordSex: pet.sex),
            isSelected: isSelected
        )
    }
}

private extension MHBPetSwitcherSpecies {
    init(abnormalRecordSpecies species: PetRecordPetSpecies) {
        switch species {
        case .dog:
            self = .dog
        case .cat:
            self = .cat
        case .other:
            self = .other
        }
    }
}

private extension MHBPetSwitcherSex {
    init(abnormalRecordSex sex: PetRecordPetSex) {
        switch sex {
        case .female:
            self = .female
        case .male:
            self = .male
        case .unknown:
            self = .unknown
        }
    }
}
