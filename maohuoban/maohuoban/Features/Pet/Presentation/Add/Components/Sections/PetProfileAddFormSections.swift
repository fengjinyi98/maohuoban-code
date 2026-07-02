import SwiftUI
import MaohuobanDesignSystem

// PetProfileAddFormSections 添加宠物表单区段
// 核心职责：
// - 组合添加宠物页面的基础资料、生活资料和备注区段
// - 保持行顺序和 row frame 锚点与父页面一致
struct PetProfileAddFormSections: View {
    let nameText: String
    let speciesText: String
    let breedText: String
    let chipNumberText: String
    let localHeroMedia: PetProfileHeroMediaDraft?
    let fallbackHeroMedia: PetProfileEditProfile.HeroMedia
    let backgroundUploadState: PetMediaUploadSlotState
    let sexText: String
    let birthDateText: String
    let arrivalDateText: String
    let weightText: String
    let neuterStatusText: String
    let personalityTags: [String]
    let noteText: String
    let isNameExpanded: Bool
    let isSpeciesExpanded: Bool
    let isBreedExpanded: Bool
    let isChipExpanded: Bool
    let isSexExpanded: Bool
    let isBirthDateExpanded: Bool
    let isArrivalDateExpanded: Bool
    let isWeightExpanded: Bool
    let isNeuterStatusExpanded: Bool
    let isTagsExpanded: Bool
    let isNoteExpanded: Bool
    let onName: () -> Void
    let onSpecies: () -> Void
    let onBreed: () -> Void
    let onChip: () -> Void
    let onBackground: () -> Void
    let onSex: () -> Void
    let onBirthDate: () -> Void
    let onArrivalDate: () -> Void
    let onWeight: () -> Void
    let onNeuterStatus: () -> Void
    let onTags: () -> Void
    let onNote: () -> Void

    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s4) {
            PetProfileAddIdentitySection(
                nameText: nameText,
                speciesText: speciesText,
                breedText: breedText,
                chipNumberText: chipNumberText,
                localHeroMedia: localHeroMedia,
                fallbackHeroMedia: fallbackHeroMedia,
                backgroundUploadState: backgroundUploadState,
                isNameExpanded: isNameExpanded,
                isSpeciesExpanded: isSpeciesExpanded,
                isBreedExpanded: isBreedExpanded,
                isChipExpanded: isChipExpanded,
                onName: onName,
                onSpecies: onSpecies,
                onBreed: onBreed,
                onChip: onChip,
                onBackground: onBackground
            )

            PetProfileAddLifeSection(
                sexText: sexText,
                birthDateText: birthDateText,
                arrivalDateText: arrivalDateText,
                weightText: weightText,
                neuterStatusText: neuterStatusText,
                isSexExpanded: isSexExpanded,
                isBirthDateExpanded: isBirthDateExpanded,
                isArrivalDateExpanded: isArrivalDateExpanded,
                isWeightExpanded: isWeightExpanded,
                isNeuterStatusExpanded: isNeuterStatusExpanded,
                onSex: onSex,
                onBirthDate: onBirthDate,
                onArrivalDate: onArrivalDate,
                onWeight: onWeight,
                onNeuterStatus: onNeuterStatus
            )

            PetProfileAddNotesSection(
                personalityTags: personalityTags,
                noteText: noteText,
                isTagsExpanded: isTagsExpanded,
                isNoteExpanded: isNoteExpanded,
                onTags: onTags,
                onNote: onNote
            )
        }
    }
}
