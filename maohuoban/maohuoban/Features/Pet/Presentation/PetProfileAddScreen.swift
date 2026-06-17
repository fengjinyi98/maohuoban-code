import SwiftUI
import MaohuobanDesignSystem
import UIKit

// PetProfileAddScreen 添加宠物档案页
// 核心职责：
// - 使用编辑档案同源的 row section 样式收集新宠物资料
// - 隐藏平台生成的宠物档案号，提交后由后端生成
struct PetProfileAddScreen: View {
    let currentUserID: String?
    let onCreated: (String) -> Void

    @Environment(\.dismiss) var dismiss
    @State var store = PetWriteStore()
    @State var mediaUploadStore = PetMediaUploadStore()
    @State var name = ""
    @State var species = PetSpecies.dog
    @State var breed = ""
    @State var chipNumber = ""
    @State var sex = PetSex.unknown
    @State var birthDate = Date.now
    @State var arrivalDate = Date.now
    @State var weight = ""
    @State var neuterStatus = "未绝育"
    @State var personalityTags: [String] = []
    @State var note = ""
    @State var localAvatarImage: UIImage?
    @State var localHeroMedia: PetProfileHeroMediaDraft?
    @State var isAvatarPreviewPresented = false
    @State var isBackgroundPreviewPresented = false
    @State var isAvatarPickerPresented = false
    @State var isBackgroundPickerPresented = false
    @State var avatarCropTarget: MHBIdentifiableUIImage?
    @State var backgroundCropTarget: MHBIdentifiableUIImage?
    @State var nameEditorDraft = ""
    @State var isNameEditorPresented = false
    @State var isNameEditorChevronExpanded = false
    @State var breedEditorDraft = ""
    @State var isBreedEditorPresented = false
    @State var isBreedEditorChevronExpanded = false
    @State var chipEditorDraft = ""
    @State var isChipEditorPresented = false
    @State var isChipEditorChevronExpanded = false
    @State var birthDateEditorDraft = Date.now
    @State var isBirthDateEditorPresented = false
    @State var isBirthDateEditorChevronExpanded = false
    @State var arrivalDateEditorDraft = Date.now
    @State var isArrivalDateEditorPresented = false
    @State var isArrivalDateEditorChevronExpanded = false
    @State var weightEditorDraft = ""
    @State var isWeightEditorPresented = false
    @State var isWeightEditorChevronExpanded = false
    @State var tagsEditorDraft: [String] = []
    @State var isTagsEditorPresented = false
    @State var isTagsEditorChevronExpanded = false
    @State var noteEditorDraft = ""
    @State var isNoteEditorPresented = false
    @State var isNoteEditorChevronExpanded = false
    @State var isSpeciesMenuPresented = false
    @State var speciesRowFrame = CGRect.zero
    @State var isSexMenuPresented = false
    @State var sexRowFrame = CGRect.zero
    @State var isNeuterStatusMenuPresented = false
    @State var neuterStatusRowFrame = CGRect.zero

    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && isMediaReadyForSave
    }

    var isMediaReadyForSave: Bool {
        let isAvatarReady = localAvatarImage == nil || mediaUploadStore.avatarState.assetID != nil
        let isBackgroundReady = localHeroMedia == nil || mediaUploadStore.backgroundState.assetID != nil
        return isAvatarReady && isBackgroundReady && !mediaUploadStore.isUploading
    }

    var isAnyMenuPresented: Bool {
        isSpeciesMenuPresented || isSexMenuPresented || isNeuterStatusMenuPresented
    }

    var suggestedPersonalityTags: [String] {
        ["亲人", "爱撒娇", "安静", "好奇", "活跃", "胆小", "黏人", "独立", "贪吃", "爱玩", "夜间活动多", "怕生"]
    }
}
