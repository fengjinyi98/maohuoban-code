import SwiftUI
import MaohuobanDesignSystem
import UIKit

// PetProfileEditScreen 宠物资料编辑页
// 核心职责：
// - 按 row section 样式展示宠物资料编辑入口
// - 保持当前阶段只承载页面设计和导航入口
struct PetProfileEditScreen: View {
    let context: PetProfileEditContext
    let currentUserID: String?
    let onPetCreated: () -> Void
    @State var store = PetWriteStore()
    @State var mediaUploadStore = PetMediaUploadStore()
    @State var selectedProfileID: String
    @State var editedNames: [String: String] = [:]
    @State var editedBreeds: [String: String] = [:]
    @State var editedChipNumbers: [String: String] = [:]
    @State var editedSexTexts: [String: String] = [:]
    @State var editedNeuterStatusTexts: [String: String] = [:]
    @State var editedBirthDates: [String: Date] = [:]
    @State var editedArrivalDates: [String: Date] = [:]
    @State var editedWeights: [String: String] = [:]
    @State var editedPersonalityTags: [String: [String]] = [:]
    @State var editedNotes: [String: String] = [:]
    @State var editedAvatarImages: [String: UIImage] = [:]
    @State var editedHeroMedia: [String: PetProfileHeroMediaDraft] = [:]
    @State var nameEditorProfileID: String?
    @State var nameEditorDraft = ""
    @State var isNameEditorPresented = false
    @State var isNameEditorChevronExpanded = false
    @State var breedEditorProfileID: String?
    @State var breedEditorDraft = ""
    @State var isBreedEditorPresented = false
    @State var isBreedEditorChevronExpanded = false
    @State var chipEditorProfileID: String?
    @State var chipEditorDraft = ""
    @State var isChipEditorPresented = false
    @State var isChipEditorChevronExpanded = false
    @State var isProfileCodeInfoPresented = false
    @State var sexPickerProfileID: String?
    @State var isSexPickerPresented = false
    @State var sexRowFrame = CGRect.zero
    @State var neuterStatusPickerProfileID: String?
    @State var isNeuterStatusPickerPresented = false
    @State var neuterStatusRowFrame = CGRect.zero
    @State var birthDateEditorProfileID: String?
    @State var birthDateEditorDraft = Date.now
    @State var isBirthDateEditorPresented = false
    @State var isBirthDateEditorChevronExpanded = false
    @State var arrivalDateEditorProfileID: String?
    @State var arrivalDateEditorDraft = Date.now
    @State var isArrivalDateEditorPresented = false
    @State var isArrivalDateEditorChevronExpanded = false
    @State var weightEditorProfileID: String?
    @State var weightEditorDraft = ""
    @State var isWeightEditorPresented = false
    @State var isWeightEditorChevronExpanded = false
    @State var tagsEditorProfileID: String?
    @State var tagsEditorDraft: [String] = []
    @State var isTagsEditorPresented = false
    @State var isTagsEditorChevronExpanded = false
    @State var noteEditorProfileID: String?
    @State var noteEditorDraft = ""
    @State var isNoteEditorPresented = false
    @State var isNoteEditorChevronExpanded = false
    @State var isAddPetPresented = false
    @State var avatarPreviewProfileID: String?
    @State var isAvatarPreviewPresented = false
    @State var backgroundPreviewProfileID: String?
    @State var isBackgroundPreviewPresented = false
    @State var deleteConfirmationProfileID: String?
    @State var isDeleteConfirmationPresented = false
    @State var homePreviewSession: PetProfileHomePreviewSession?
    @State var homePreviewPreparationID: UUID?
    @State var isHomePreviewPreparing = false
    @State var homePreviewHeroImageWidth: CGFloat = 393

    init(
        context: PetProfileEditContext,
        currentUserID: String? = nil,
        onPetCreated: @escaping () -> Void = {}
    ) {
        self.context = context
        self.currentUserID = currentUserID
        self.onPetCreated = onPetCreated
        _selectedProfileID = State(initialValue: context.selectedProfile.id)
    }

    var selectedProfile: PetProfileEditProfile {
        context.profiles.first(where: { $0.id == selectedProfileID }) ?? context.selectedProfile
    }

    var avatarPreviewProfile: PetProfileEditProfile {
        guard let avatarPreviewProfileID,
              let profile = context.profiles.first(where: { $0.id == avatarPreviewProfileID })
        else {
            return selectedProfile
        }

        return profile
    }

    var backgroundPreviewProfile: PetProfileEditProfile {
        guard let backgroundPreviewProfileID,
              let profile = context.profiles.first(where: { $0.id == backgroundPreviewProfileID })
        else {
            return selectedProfile
        }

        return profile
    }

    var deleteConfirmationProfile: PetProfileEditProfile {
        guard let deleteConfirmationProfileID,
              let profile = context.profiles.first(where: { $0.id == deleteConfirmationProfileID })
        else {
            return selectedProfile
        }

        return profile
    }

    var canSave: Bool {
        !store.isSubmitting
            && !displayName(for: selectedProfile).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
