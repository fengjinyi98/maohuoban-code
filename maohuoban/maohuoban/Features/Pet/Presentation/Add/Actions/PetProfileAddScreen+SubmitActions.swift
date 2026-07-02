import MaohuobanDiagnostics
import SwiftUI

extension PetProfileAddScreen {
    func submit() async {
        let bindings = mediaUploadStore.uploadedBindings
        await Diagnostics.track(
            "pet.create_submit_started",
            properties: [
                "user_id_prefix": .string(currentUserID?.diagnosticsPrefix ?? ""),
                "breed_length_non_whitespace": .int(breed.filter { !$0.isWhitespace }.count),
                "has_avatar_asset": .bool(bindings.avatarAssetID != nil),
                "has_background_asset": .bool(bindings.backgroundAssetID != nil),
                "background_media_kind": .string(localHeroMedia?.diagnosticsKind ?? "")
            ]
        )
        await store.createPetWithUploadedMedia(
            draft: PetProfileDraft(
                name: name,
                species: species,
                breed: breed,
                sex: sex,
                birthday: PetWriteFormatters.birthdayString(from: birthDate),
                microchipNumber: chipNumber,
                arrivalDate: formattedDate(arrivalDate),
                weightGrams: submitWeightGrams,
                neuterStatus: submitNeuterStatus,
                personalityTags: personalityTags,
                note: note
            ),
            mediaBindings: bindings,
            currentUserID: currentUserID
        )

        if case .createdPet(let petID) = store.phase {
            await Diagnostics.track(
                "pet.create_submit_succeeded",
                properties: [
                    "pet_id_prefix": .string(petID.diagnosticsPrefix),
                    "breed_length_non_whitespace": .int(breed.filter { !$0.isWhitespace }.count),
                    "has_avatar_asset": .bool(bindings.avatarAssetID != nil),
                    "has_background_asset": .bool(bindings.backgroundAssetID != nil)
                ]
            )
            onCreated(petID)
            dismiss()
        } else if case .failed = store.phase {
            await Diagnostics.track(
                "pet.create_submit_failed",
                properties: [
                    "breed_length_non_whitespace": .int(breed.filter { !$0.isWhitespace }.count),
                    "has_avatar_asset": .bool(bindings.avatarAssetID != nil),
                    "has_background_asset": .bool(bindings.backgroundAssetID != nil)
                ]
            )
        }
    }
}

private extension String {
    var diagnosticsPrefix: String {
        String(prefix(8))
    }
}

private extension PetProfileHeroMediaDraft {
    var diagnosticsKind: String {
        switch self {
        case .image:
            "image"
        case .video:
            "video"
        case .livePhoto:
            "live_photo"
        }
    }
}
