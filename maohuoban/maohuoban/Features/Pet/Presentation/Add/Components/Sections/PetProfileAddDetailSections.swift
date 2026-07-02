import SwiftUI

// PetProfileAddIdentitySection 添加宠物身份资料区段
// 核心职责：
// - 展示名称、类型、品种、芯片号和背景入口
// - 维护类型菜单锚点采集位置
struct PetProfileAddIdentitySection: View {
    let nameText: String
    let speciesText: String
    let breedText: String
    let chipNumberText: String
    let localHeroMedia: PetProfileHeroMediaDraft?
    let fallbackHeroMedia: PetProfileEditProfile.HeroMedia
    let backgroundUploadState: PetMediaUploadSlotState
    let isNameExpanded: Bool
    let isSpeciesExpanded: Bool
    let isBreedExpanded: Bool
    let isChipExpanded: Bool
    let onName: () -> Void
    let onSpecies: () -> Void
    let onBreed: () -> Void
    let onChip: () -> Void
    let onBackground: () -> Void

    var body: some View {
        PetProfileAddSection {
            PetProfileAddRow(
                title: "宠物名字",
                isAccessoryExpanded: isNameExpanded,
                action: onName
            ) {
                PetProfileAddValueText(value: nameText)
            }

            PetProfileAddRow(
                title: "宠物类型",
                isAccessoryExpanded: isSpeciesExpanded,
                action: onSpecies
            ) {
                PetProfileAddValueText(value: speciesText)
            }
            .petProfileAddRowFrame(.species)

            PetProfileAddRow(
                title: "宠物品种",
                isAccessoryExpanded: isBreedExpanded,
                action: onBreed
            ) {
                PetProfileAddValueText(value: breedText)
            }

            PetProfileAddRow(
                title: "芯片号",
                isAccessoryExpanded: isChipExpanded,
                action: onChip
            ) {
                PetProfileAddValueText(value: chipNumberText)
            }

            PetProfileAddRow(
                title: "背景",
                showsSeparator: false,
                action: onBackground
            ) {
                if let localHeroMedia {
                    PetProfileEditMediaThumbnail(
                        media: fallbackHeroMedia,
                        localMedia: localHeroMedia,
                        uploadState: backgroundUploadState
                    )
                } else {
                    PetProfileAddValueText(value: "未设置")
                }
            }
        }
    }
}

// PetProfileAddLifeSection 添加宠物生活资料区段
// 核心职责：
// - 展示性别、日期、体重和绝育状态
// - 维护弹出菜单所需 row frame 锚点
struct PetProfileAddLifeSection: View {
    let sexText: String
    let birthDateText: String
    let arrivalDateText: String
    let weightText: String
    let neuterStatusText: String
    let isSexExpanded: Bool
    let isBirthDateExpanded: Bool
    let isArrivalDateExpanded: Bool
    let isWeightExpanded: Bool
    let isNeuterStatusExpanded: Bool
    let onSex: () -> Void
    let onBirthDate: () -> Void
    let onArrivalDate: () -> Void
    let onWeight: () -> Void
    let onNeuterStatus: () -> Void

    var body: some View {
        PetProfileAddSection {
            PetProfileAddRow(
                title: "性别",
                isAccessoryExpanded: isSexExpanded,
                action: onSex
            ) {
                PetProfileAddValueText(value: sexText)
            }
            .petProfileAddRowFrame(.sex)

            PetProfileAddRow(
                title: "出生日期",
                isAccessoryExpanded: isBirthDateExpanded,
                action: onBirthDate
            ) {
                PetProfileAddValueText(value: birthDateText)
            }

            PetProfileAddRow(
                title: "到家时间",
                isAccessoryExpanded: isArrivalDateExpanded,
                action: onArrivalDate
            ) {
                PetProfileAddValueText(value: arrivalDateText)
            }

            PetProfileAddRow(
                title: "体重",
                isAccessoryExpanded: isWeightExpanded,
                action: onWeight
            ) {
                PetProfileAddValueText(value: weightText)
            }

            PetProfileAddRow(
                title: "绝育状态",
                showsSeparator: false,
                isAccessoryExpanded: isNeuterStatusExpanded,
                action: onNeuterStatus
            ) {
                PetProfileAddValueText(value: neuterStatusText)
            }
            .petProfileAddRowFrame(.neuterStatus)
        }
    }
}

// PetProfileAddNotesSection 添加宠物标签备注区段
// 核心职责：
// - 展示性格标签和备注入口
// - 保持备注分组的最后一行无分隔线
struct PetProfileAddNotesSection: View {
    let personalityTags: [String]
    let noteText: String
    let isTagsExpanded: Bool
    let isNoteExpanded: Bool
    let onTags: () -> Void
    let onNote: () -> Void

    var body: some View {
        PetProfileAddSection {
            PetProfileAddRow(
                title: "性格标签",
                isAccessoryExpanded: isTagsExpanded,
                action: onTags
            ) {
                PetProfileAddTagFlow(tags: personalityTags)
            }

            PetProfileAddRow(
                title: "备注",
                showsSeparator: false,
                isAccessoryExpanded: isNoteExpanded,
                action: onNote
            ) {
                PetProfileAddValueText(value: noteText)
            }
        }
    }
}
