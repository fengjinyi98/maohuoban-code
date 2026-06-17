import SwiftUI

extension PetProfileEditScreen {
    func displayName(for profile: PetProfileEditProfile) -> String {
        editedNames[profile.id] ?? profile.name
    }

    func displayChipNumber(for profile: PetProfileEditProfile) -> String {
        let chipNumber = editedChipNumbers[profile.id] ?? profile.chipNumber
        let trimmedChipNumber = chipNumber.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedChipNumber.isEmpty || trimmedChipNumber == "暂未录入" || trimmedChipNumber == "未添加" {
            return ""
        }

        return trimmedChipNumber
    }

    func displaySexText(for profile: PetProfileEditProfile) -> String {
        let sexText = editedSexTexts[profile.id] ?? profile.sexText

        return switch sexText {
        case "男", "公": "公"
        case "女", "母": "母"
        default: "未知"
        }
    }

    func displayNeuterStatusText(for profile: PetProfileEditProfile) -> String {
        let neuterStatusText = editedNeuterStatusTexts[profile.id] ?? profile.neuterStatusText

        return switch neuterStatusText {
        case "已绝育": "已绝育"
        default: "未绝育"
        }
    }

    func displayBirthDateText(for profile: PetProfileEditProfile) -> String {
        if let date = editedBirthDates[profile.id] {
            return formattedDate(date)
        }

        return normalizedDateText(profile.birthDateText)
    }

    func displayArrivalDateText(for profile: PetProfileEditProfile) -> String {
        if let date = editedArrivalDates[profile.id] {
            return formattedDate(date)
        }

        return normalizedDateText(profile.arrivalDateText)
    }

    func displayWeightText(for profile: PetProfileEditProfile) -> String {
        let weightText = editedWeights[profile.id] ?? profile.weightText
        let trimmedWeightText = weightText.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedWeightText.isEmpty || trimmedWeightText == "暂未记录" || trimmedWeightText == "暂未设置" {
            return "暂未记录"
        }

        if trimmedWeightText.lowercased().hasSuffix("kg") {
            return trimmedWeightText
        }

        return "\(trimmedWeightText) kg"
    }

    func displayPersonalityTags(for profile: PetProfileEditProfile) -> [String] {
        editedPersonalityTags[profile.id] ?? profile.personalityTags
    }

    func displayNoteText(for profile: PetProfileEditProfile) -> String {
        let noteText = editedNotes[profile.id] ?? profile.note
        let trimmedNoteText = noteText.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedNoteText.isEmpty || trimmedNoteText == "暂未设置" {
            return "暂无"
        }

        return trimmedNoteText
    }

    func normalizedDateText(_ dateText: String) -> String {
        let trimmedDateText = dateText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedDateText.isEmpty ? "暂未设置" : trimmedDateText
    }

    func date(from dateText: String) -> Date? {
        let components = dateText.split(separator: "-").compactMap { Int($0) }
        guard components.count == 3 else {
            return nil
        }

        var dateComponents = DateComponents()
        dateComponents.calendar = Calendar(identifier: .gregorian)
        dateComponents.year = components[0]
        dateComponents.month = components[1]
        dateComponents.day = components[2]

        return dateComponents.date
    }

    func formattedDate(_ date: Date) -> String {
        let components = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: date)
        guard let year = components.year,
              let month = components.month,
              let day = components.day else {
            return "暂未设置"
        }

        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    func draftWeightText(from weightText: String) -> String {
        let trimmedWeightText = weightText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedWeightText.isEmpty || trimmedWeightText == "暂未记录" || trimmedWeightText == "暂未设置" {
            return ""
        }

        return trimmedWeightText
            .replacingOccurrences(of: "kg", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func petSex(from sexText: String) -> PetSex {
        switch sexText {
        case "公": .male
        case "母": .female
        default: .unknown
        }
    }

    func petNeuterStatus(from neuterStatusText: String) -> PetNeuterStatus {
        switch neuterStatusText {
        case "已绝育": .neutered
        case "未绝育": .intact
        default: .unknown
        }
    }

    func optionalDateText(_ dateText: String) -> String {
        dateText == "暂未设置" ? "" : dateText
    }

    func optionalNoteText(_ noteText: String) -> String {
        noteText == "暂无" ? "" : noteText
    }

    func weightGrams(from weightText: String) -> Int? {
        let normalizedWeightText = draftWeightText(from: weightText)
        guard let weight = Double(normalizedWeightText) else {
            return nil
        }

        return Int((weight * 1000).rounded())
    }

    func formattedProfileCode(_ profileCode: String) -> String {
        let digits = profileCode.filter { character in
            character.unicodeScalars.count == 1
                && character.unicodeScalars.first.map { (48...57).contains($0.value) } == true
        }

        guard digits.count == 16 else {
            return profileCode
        }

        let first = digits.prefix(3)
        let secondStart = digits.index(digits.startIndex, offsetBy: 3)
        let secondEnd = digits.index(secondStart, offsetBy: 3)
        let thirdEnd = digits.index(secondEnd, offsetBy: 2)
        let fourthEnd = digits.index(thirdEnd, offsetBy: 7)

        return [
            String(first),
            String(digits[secondStart..<secondEnd]),
            String(digits[secondEnd..<thirdEnd]),
            String(digits[thirdEnd..<fourthEnd]),
            String(digits[fourthEnd...])
        ].joined(separator: "-")
    }

    func deleteConfirmationPhrase(for petName: String) -> String {
        "我确认删除\(petName)"
    }
}
