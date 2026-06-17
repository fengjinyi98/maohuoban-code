import SwiftUI

extension PetProfileEditScreen {
    var suggestedPersonalityTags: [String] {
        ["亲人", "爱撒娇", "安静", "好奇", "活跃", "胆小", "黏人", "独立", "贪吃", "爱玩", "夜间活动多", "怕生"]
    }

    func showBirthDateEditor(for profile: PetProfileEditProfile) {
        dismissSelectionMenus()
        birthDateEditorProfileID = profile.id
        birthDateEditorDraft = editedBirthDates[profile.id] ?? date(from: profile.birthDateText) ?? Date.now
        isBirthDateEditorChevronExpanded = true
        isBirthDateEditorPresented = true
    }

    func showBreedEditor(for profile: PetProfileEditProfile) {
        dismissSelectionMenus()
        breedEditorProfileID = profile.id
        breedEditorDraft = editedBreeds[profile.id] ?? profile.breed
        isBreedEditorChevronExpanded = true
        isBreedEditorPresented = true
    }

    func showArrivalDateEditor(for profile: PetProfileEditProfile) {
        dismissSelectionMenus()
        arrivalDateEditorProfileID = profile.id
        arrivalDateEditorDraft = editedArrivalDates[profile.id] ?? date(from: profile.arrivalDateText) ?? Date.now
        isArrivalDateEditorChevronExpanded = true
        isArrivalDateEditorPresented = true
    }

    func showWeightEditor(for profile: PetProfileEditProfile) {
        dismissSelectionMenus()
        weightEditorProfileID = profile.id
        weightEditorDraft = draftWeightText(from: editedWeights[profile.id] ?? profile.weightText)
        isWeightEditorChevronExpanded = true
        isWeightEditorPresented = true
    }

    func showTagsEditor(for profile: PetProfileEditProfile) {
        dismissSelectionMenus()
        tagsEditorProfileID = profile.id
        tagsEditorDraft = displayPersonalityTags(for: profile)
        isTagsEditorChevronExpanded = true
        isTagsEditorPresented = true
    }

    func showNoteEditor(for profile: PetProfileEditProfile) {
        dismissSelectionMenus()
        noteEditorProfileID = profile.id
        let noteText = editedNotes[profile.id] ?? profile.note
        noteEditorDraft = noteText == "暂未设置" ? "" : noteText
        isNoteEditorChevronExpanded = true
        isNoteEditorPresented = true
    }

    func showSexPicker(for profileID: String) {
        let isOpeningSamePicker = isSexPickerPresented && sexPickerProfileID == profileID
        dismissSelectionMenus()

        if !isOpeningSamePicker {
            sexPickerProfileID = profileID
            isSexPickerPresented = true
        }
    }

    func showSpeciesPicker(for profileID: String) {
        let isOpeningSamePicker = isSpeciesPickerPresented && speciesPickerProfileID == profileID
        dismissSelectionMenus()

        if !isOpeningSamePicker {
            speciesPickerProfileID = profileID
            isSpeciesPickerPresented = true
        }
    }

    func showNeuterStatusPicker(for profileID: String) {
        let isOpeningSamePicker = isNeuterStatusPickerPresented && neuterStatusPickerProfileID == profileID
        dismissSelectionMenus()

        if !isOpeningSamePicker {
            neuterStatusPickerProfileID = profileID
            isNeuterStatusPickerPresented = true
        }
    }

    func dismissSelectionMenus() {
        isSpeciesPickerPresented = false
        speciesPickerProfileID = nil
        isSexPickerPresented = false
        sexPickerProfileID = nil
        isNeuterStatusPickerPresented = false
        neuterStatusPickerProfileID = nil
    }

    func updateSpeciesText(_ speciesText: String) {
        guard let profileID = speciesPickerProfileID else { return }
        Task {
            await saveSpeciesText(speciesText, for: profileID)
        }
    }

    func updateSexText(_ sexText: String) {
        guard let profileID = sexPickerProfileID else { return }
        Task {
            await saveSexText(sexText, for: profileID)
        }
    }

    func updateNeuterStatusText(_ neuterStatusText: String) {
        guard let profileID = neuterStatusPickerProfileID else { return }
        Task {
            await saveNeuterStatusText(neuterStatusText, for: profileID)
        }
    }
}
