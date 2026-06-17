import SwiftUI
import MaohuobanDesignSystem

extension PetProfileAddScreen {
    var speciesDisplayText: String {
        switch species {
        case .dog: "狗狗"
        case .cat: "猫咪"
        case .other: "其他"
        }
    }

    var sexDisplayText: String {
        switch sex {
        case .male: "公"
        case .female: "母"
        case .unknown: "未知"
        }
    }

    var displayWeightText: String {
        let trimmedWeight = weight.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedWeight.isEmpty ? "暂未记录" : "\(trimmedWeight) kg"
    }

    func showNameEditor() {
        dismissSelectionMenus()
        nameEditorDraft = name
        isNameEditorChevronExpanded = true
        isNameEditorPresented = true
    }

    func showChipEditor() {
        dismissSelectionMenus()
        chipEditorDraft = chipNumber
        isChipEditorChevronExpanded = true
        isChipEditorPresented = true
    }

    func showBirthDateEditor() {
        dismissSelectionMenus()
        birthDateEditorDraft = birthDate
        isBirthDateEditorChevronExpanded = true
        isBirthDateEditorPresented = true
    }

    func showArrivalDateEditor() {
        dismissSelectionMenus()
        arrivalDateEditorDraft = arrivalDate
        isArrivalDateEditorChevronExpanded = true
        isArrivalDateEditorPresented = true
    }

    func showWeightEditor() {
        dismissSelectionMenus()
        weightEditorDraft = weight
        isWeightEditorChevronExpanded = true
        isWeightEditorPresented = true
    }

    func showTagsEditor() {
        dismissSelectionMenus()
        tagsEditorDraft = personalityTags
        isTagsEditorChevronExpanded = true
        isTagsEditorPresented = true
    }

    func showNoteEditor() {
        dismissSelectionMenus()
        noteEditorDraft = note
        isNoteEditorChevronExpanded = true
        isNoteEditorPresented = true
    }

    func toggleSpeciesMenu() {
        let shouldOpen = !isSpeciesMenuPresented
        dismissSelectionMenus()
        isSpeciesMenuPresented = shouldOpen
    }

    func toggleSexMenu() {
        let shouldOpen = !isSexMenuPresented
        dismissSelectionMenus()
        isSexMenuPresented = shouldOpen
    }

    func toggleNeuterStatusMenu() {
        let shouldOpen = !isNeuterStatusMenuPresented
        dismissSelectionMenus()
        isNeuterStatusMenuPresented = shouldOpen
    }

    func dismissSelectionMenus() {
        isSpeciesMenuPresented = false
        isSexMenuPresented = false
        isNeuterStatusMenuPresented = false
    }

    func updateSpecies(_ value: String) {
        species = switch value {
        case "猫咪": .cat
        case "其他": .other
        default: .dog
        }
        isSpeciesMenuPresented = false
    }

    func updateSex(_ value: String) {
        sex = switch value {
        case "公": .male
        case "母": .female
        default: .unknown
        }
        isSexMenuPresented = false
    }

    func updateNeuterStatus(_ value: String) {
        neuterStatus = value
        isNeuterStatusMenuPresented = false
    }

    func formattedDate(_ date: Date) -> String {
        date.formatted(
            .iso8601
                .year()
                .month()
                .day()
                .dateSeparator(.dash)
        )
    }

    func submit() async {
        await store.createPet(
            draft: PetProfileDraft(
                name: name,
                species: species,
                breed: "",
                sex: sex,
                birthday: PetWriteFormatters.birthdayString(from: birthDate)
            ),
            currentUserID: currentUserID
        )

        if case .createdPet = store.phase {
            onCreated()
        }
    }
}
