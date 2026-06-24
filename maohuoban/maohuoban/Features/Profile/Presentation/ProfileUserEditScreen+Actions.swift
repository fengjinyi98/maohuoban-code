import SwiftUI
import MaohuobanDesignSystem
import MaohuobanDiagnostics
import UIKit

// ProfileUserEditScreen 动作扩展
// 核心职责：
// - 承载编辑页的展示数据计算、保存操作、Toast 反馈和媒体上传
extension ProfileUserEditScreen {

    // MARK: - Computed Display Values

    var displayNameValue: String {
        currentUserStore.displayName
    }

    var maohuobanIDValue: String {
        currentUserStore.maohuobanID
    }

    var bioValue: String {
        currentUserStore.bio
    }

    var currentGenderOption: ProfileUserEditGenderOption? {
        ProfileUserEditGenderOption.fromStoredValue(currentUserStore.gender)
    }

    var currentGenderVisible: Bool {
        currentUserStore.isGenderVisible
    }

    var birthdayTextValue: String? {
        currentUserStore.birthdayDisplayText ?? currentUserStore.birthday
    }

    var birthdayDateValue: Date? {
        ProfileUserEditBirthdayDateCodec.date(from: currentUserStore.birthday ?? "")
    }

    // MARK: - Save Actions

    func saveDisplayName() {
        let value = nameEditorDraft
        Task {
            let saved = await editStore.updateDisplayName(value)
            showProfileToast(success: saved)
        }
    }

    func saveBio() {
        let value = bioEditorDraft
        Task {
            let saved = await editStore.updateBio(value)
            showProfileToast(success: saved)
        }
    }

    func saveGender() {
        let gender = genderEditorDraft?.rawValue ?? ProfileUserEditGenderOption.unknown.rawValue
        let isVisible = isGenderVisibleDraft
        Task {
            let saved = await editStore.updateGender(gender, isVisible: isVisible)
            showProfileToast(success: saved)
        }
    }

    func saveBirthday() {
        let birthday = ProfileUserEditBirthdayDateCodec.string(from: birthdayEditorDraft)
        Task {
            let saved = await editStore.updateBirthday(birthday)
            showProfileToast(success: saved)
        }
    }

    // MARK: - Toast

    func showProfileToast(success: Bool) {
        guard let message = editStore.toastMessage else { return }
        if success {
            MHBToastPresenter().success(message)
        } else {
            MHBToastPresenter().danger(message)
        }
    }

    // MARK: - Media Upload

    @MainActor
    func uploadAvatarImage(_ image: UIImage) async -> Bool {
        let encodeStartedAt = Date()
        await Diagnostics.track(
            "profile.avatar_upload.encode_started",
            properties: [
                "issue_tag": .string("ProfileAvatarUpload"),
                "pixel_width": .int(Int(image.size.width * image.scale)),
                "pixel_height": .int(Int(image.size.height * image.scale)),
                "scale": .double(Double(image.scale)),
                "has_cg_image": .bool(image.cgImage != nil),
                "is_main_actor": .bool(true)
            ]
        )
        guard let encoded = MHBMediaUploadEncoder.encode(
            image: image,
            purpose: .avatar,
            fileName: "profile-avatar"
        ) else {
            let elapsedMs = Int(Date().timeIntervalSince(encodeStartedAt) * 1_000)
            await Diagnostics.track(
                "profile.avatar_upload.encode_failed",
                properties: [
                    "issue_tag": .string("ProfileAvatarUpload"),
                    "duration_ms": .int(elapsedMs)
                ]
            )
            editStore.toastMessage = "头像保存失败，请重试"
            showProfileToast(success: false)
            return false
        }

        let encodeElapsedMs = Int(Date().timeIntervalSince(encodeStartedAt) * 1_000)
        await Diagnostics.track(
            "profile.avatar_upload.encode_succeeded",
            properties: [
                "issue_tag": .string("ProfileAvatarUpload"),
                "duration_ms": .int(encodeElapsedMs),
                "encoded_bytes": .int(encoded.data.count),
                "mime_type": .string(encoded.mimeType),
                "file_name": .string(encoded.fileName),
                "pixel_width": .int(encoded.pixelWidth),
                "pixel_height": .int(encoded.pixelHeight),
                "quality": .double(Double(encoded.quality))
            ]
        )
        let draft = CurrentUserProfileMediaUploadDraft(
            fileName: encoded.fileName,
            mimeType: encoded.mimeType,
            content: encoded.data,
            sourceClient: "ios"
        )
        let uploadStartedAt = Date()
        await Diagnostics.track(
            "profile.avatar_upload.store_started",
            properties: [
                "issue_tag": .string("ProfileAvatarUpload"),
                "encoded_bytes": .int(draft.content.count),
                "mime_type": .string(draft.mimeType),
                "file_name": .string(draft.fileName)
            ]
        )
        let saved = await editStore.uploadAvatar(draft: draft)
        if saved {
            editedAvatarImage = image
        }
        let uploadElapsedMs = Int(Date().timeIntervalSince(uploadStartedAt) * 1_000)
        await Diagnostics.track(
            "profile.avatar_upload.store_finished",
            properties: [
                "issue_tag": .string("ProfileAvatarUpload"),
                "success": .bool(saved),
                "duration_ms": .int(uploadElapsedMs),
                "toast_message": .string(editStore.toastMessage ?? "")
            ]
        )
        showProfileToast(success: saved)
        return saved
    }

    @MainActor
    func uploadCoverImage(_ image: UIImage) async -> Bool {
        guard let encoded = MHBMediaUploadEncoder.encode(
            image: image,
            purpose: .cover,
            fileName: "profile-cover"
        ) else {
            editStore.toastMessage = "背景保存失败，请重试"
            showProfileToast(success: false)
            return false
        }

        let draft = CurrentUserProfileMediaUploadDraft(
            fileName: encoded.fileName,
            mimeType: encoded.mimeType,
            content: encoded.data,
            sourceClient: "ios"
        )
        let saved = await editStore.uploadCover(draft: draft)
        if saved {
            editedCoverImage = image
        }
        showProfileToast(success: saved)
        return saved
    }
}
