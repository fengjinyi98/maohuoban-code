import Foundation
import MaohuobanDiagnostics
import Observation

// PetMediaUploadStore 宠物媒体上传状态模型
// 核心职责：
// - 统一管理添加和编辑档案的媒体上传状态
// - 暴露保存按钮禁用和进度遮罩所需数据
@MainActor
@Observable
final class PetMediaUploadStore {
    var avatarState: PetMediaUploadSlotState = .idle
    var backgroundState: PetMediaUploadSlotState = .idle

    var isUploading: Bool {
        avatarState.isUploading || backgroundState.isUploading
    }

    var uploadedBindings: PetUploadedMediaBindings {
        PetUploadedMediaBindings(
            avatarAssetID: avatarState.assetID,
            backgroundAssetID: backgroundState.assetID
        )
    }

    private let repository: PetRepository

    init(repository: PetRepository = DefaultPetRepository()) {
        self.repository = repository
    }

    func uploadAvatar(
        draft: PetMediaUploadDraft,
        currentUserID: String?
    ) async -> Bool {
        await uploadPendingMedia(
            debugKind: "avatar",
            draft: draft,
            currentUserID: currentUserID,
            setState: { self.avatarState = $0 },
            perform: repository.uploadPendingAvatar
        )
    }

    func uploadBackgroundImage(
        draft: PetMediaUploadDraft,
        currentUserID: String?
    ) async -> Bool {
        await uploadPendingMedia(
            debugKind: "backgroundImage",
            draft: draft,
            currentUserID: currentUserID,
            setState: { self.backgroundState = $0 },
            perform: repository.uploadPendingBackgroundImage
        )
    }

    func uploadBackgroundVideo(
        draft: PetMediaUploadDraft,
        currentUserID: String?
    ) async -> Bool {
        await uploadPendingMedia(
            debugKind: "backgroundVideo",
            draft: draft,
            currentUserID: currentUserID,
            setState: { self.backgroundState = $0 },
            perform: repository.uploadPendingBackgroundVideo
        )
    }

    func uploadBackgroundLivePhoto(
        draft: PetLivePhotoUploadDraft,
        currentUserID: String?
    ) async -> Bool {
        await uploadPendingLivePhoto(
            debugKind: "backgroundLivePhoto",
            draft: draft,
            currentUserID: currentUserID,
            setState: { self.backgroundState = $0 },
            perform: repository.uploadPendingBackgroundLivePhoto
        )
    }

    func bindUploadedMedia(
        petID: String,
        assetID: String,
        currentUserID: String?
    ) async -> Bool {
        guard let currentUserID, !currentUserID.isEmpty else {
            await Diagnostics.track(
                "pet.media_bind_rejected",
                properties: [
                    "reason": "missing_user",
                    "pet_id_prefix": .string(petID.diagnosticsPrefix),
                    "asset_id_prefix": .string(assetID.diagnosticsPrefix)
                ]
            )
            return false
        }
        do {
            let response = try await repository.bindUploadedMedia(
                petID: petID,
                assetID: assetID,
                currentUserID: currentUserID
            )
            await Diagnostics.track(
                "pet.media_bind_succeeded",
                properties: [
                    "pet_id_prefix": .string(petID.diagnosticsPrefix),
                    "asset_id_prefix": .string(assetID.diagnosticsPrefix),
                    "user_id_prefix": .string(currentUserID.diagnosticsPrefix),
                    "usage_kind": .string(response.data?.asset.usageKind.rawValue ?? ""),
                    "has_binding": .bool(response.data?.binding != nil)
                ]
            )
            return true
        } catch {
            await Diagnostics.track(
                "pet.media_bind_failed",
                properties: [
                    "pet_id_prefix": .string(petID.diagnosticsPrefix),
                    "asset_id_prefix": .string(assetID.diagnosticsPrefix),
                    "user_id_prefix": .string(currentUserID.diagnosticsPrefix),
                    "error_kind": .string(error.diagnosticsKind)
                ]
            )
            return false
        }
    }

    private func uploadPendingMedia(
        debugKind: String,
        draft: PetMediaUploadDraft,
        currentUserID: String?,
        setState: @escaping (PetMediaUploadSlotState) -> Void,
        perform: (
            PetMediaUploadDraft,
            String,
            (@MainActor (Double) -> Void)?
        ) async throws(MHBAPIError) -> MHBAPIResponse<PetMediaUploadResult>
    ) async -> Bool {
        guard let currentUserID, !currentUserID.isEmpty else {
            setState(.failed("请先登录"))
            await Diagnostics.track(
                "pet.media_upload_rejected",
                properties: [
                    "media_slot": .string(debugKind),
                    "reason": "missing_user",
                    "mime_type": .string(draft.mimeType),
                    "byte_size": .int(draft.content.count)
                ]
            )
            return false
        }
        guard !draft.content.isEmpty else {
            setState(.failed("媒体数据为空"))
            await Diagnostics.track(
                "pet.media_upload_rejected",
                properties: [
                    "media_slot": .string(debugKind),
                    "reason": "empty_content",
                    "user_id_prefix": .string(currentUserID.diagnosticsPrefix),
                    "mime_type": .string(draft.mimeType)
                ]
            )
            return false
        }
        setState(.uploading(progress: 0))
        await Diagnostics.track(
            "pet.media_upload_started",
            properties: [
                "media_slot": .string(debugKind),
                "user_id_prefix": .string(currentUserID.diagnosticsPrefix),
                "file_extension": .string((draft.fileName as NSString).pathExtension.lowercased()),
                "mime_type": .string(draft.mimeType),
                "byte_size": .int(draft.content.count)
            ]
        )
        var lastProgressBucket = -1
        do {
            let response = try await perform(draft, currentUserID) { progress in
                setState(.uploading(progress: progress))
                let progressBucket = Int((min(max(progress, 0), 1) * 100) / 25) * 25
                guard progressBucket != lastProgressBucket else {
                    return
                }
                lastProgressBucket = progressBucket
                Task {
                    await Diagnostics.track(
                        "pet.media_upload_progress",
                        properties: [
                            "media_slot": .string(debugKind),
                            "progress_percent": .int(progressBucket)
                        ]
                    )
                }
            }
            guard let upload = response.data else {
                setState(.failed("媒体数据为空"))
                await Diagnostics.track(
                    "pet.media_upload_failed",
                    properties: [
                        "media_slot": .string(debugKind),
                        "user_id_prefix": .string(currentUserID.diagnosticsPrefix),
                        "reason": "missing_response_data",
                        "api_code": .string(response.code)
                    ]
                )
                return false
            }
            setState(.uploaded(upload))
            await Diagnostics.track(
                "pet.media_upload_succeeded",
                properties: [
                    "media_slot": .string(debugKind),
                    "user_id_prefix": .string(currentUserID.diagnosticsPrefix),
                    "asset_id_prefix": .string(upload.asset.id.diagnosticsPrefix),
                    "usage_kind": .string(upload.asset.usageKind.rawValue),
                    "mime_type": .string(upload.asset.mimeType),
                    "byte_size": .int(upload.asset.byteSize),
                    "width": .int(upload.asset.width ?? 0),
                    "height": .int(upload.asset.height ?? 0),
                    "derivative_count": .int(upload.derivatives.count),
                    "has_theme_color": .bool(upload.themeColorHex != nil),
                    "has_cover_frame": .bool(upload.coverFrame != nil)
                ]
            )
            return true
        } catch {
            setState(.failed(error.toastMessage))
            await Diagnostics.track(
                "pet.media_upload_failed",
                properties: [
                    "media_slot": .string(debugKind),
                    "user_id_prefix": .string(currentUserID.diagnosticsPrefix),
                    "mime_type": .string(draft.mimeType),
                    "byte_size": .int(draft.content.count),
                    "error_kind": .string(error.diagnosticsKind)
                ]
            )
            return false
        }
    }

    private func uploadPendingLivePhoto(
        debugKind: String,
        draft: PetLivePhotoUploadDraft,
        currentUserID: String?,
        setState: @escaping (PetMediaUploadSlotState) -> Void,
        perform: (
            PetLivePhotoUploadDraft,
            String,
            (@MainActor (Double) -> Void)?
        ) async throws(MHBAPIError) -> MHBAPIResponse<PetMediaUploadResult>
    ) async -> Bool {
        guard let currentUserID, !currentUserID.isEmpty else {
            setState(.failed("请先登录"))
            await Diagnostics.track(
                "pet.media_upload_rejected",
                properties: [
                    "media_slot": .string(debugKind),
                    "reason": "missing_user",
                    "byte_size": .int(draft.byteSize)
                ]
            )
            return false
        }
        guard !draft.still.content.isEmpty, !draft.pairedVideo.content.isEmpty else {
            setState(.failed("媒体数据为空"))
            await Diagnostics.track(
                "pet.media_upload_rejected",
                properties: [
                    "media_slot": .string(debugKind),
                    "reason": "empty_content",
                    "user_id_prefix": .string(currentUserID.diagnosticsPrefix),
                    "byte_size": .int(draft.byteSize)
                ]
            )
            return false
        }
        setState(.uploading(progress: 0))
        await Diagnostics.track(
            "pet.media_upload_started",
            properties: [
                "media_slot": .string(debugKind),
                "user_id_prefix": .string(currentUserID.diagnosticsPrefix),
                "file_extension": .string((draft.still.fileName as NSString).pathExtension.lowercased()),
                "mime_type": .string(draft.still.mimeType),
                "paired_video_extension": .string((draft.pairedVideo.fileName as NSString).pathExtension.lowercased()),
                "paired_video_mime_type": .string(draft.pairedVideo.mimeType),
                "byte_size": .int(draft.byteSize)
            ]
        )
        var lastProgressBucket = -1
        do {
            let response = try await perform(draft, currentUserID) { progress in
                setState(.uploading(progress: progress))
                let progressBucket = Int((min(max(progress, 0), 1) * 100) / 25) * 25
                guard progressBucket != lastProgressBucket else {
                    return
                }
                lastProgressBucket = progressBucket
                Task {
                    await Diagnostics.track(
                        "pet.media_upload_progress",
                        properties: [
                            "media_slot": .string(debugKind),
                            "progress_percent": .int(progressBucket)
                        ]
                    )
                }
            }
            guard let upload = response.data else {
                setState(.failed("媒体数据为空"))
                await Diagnostics.track(
                    "pet.media_upload_failed",
                    properties: [
                        "media_slot": .string(debugKind),
                        "user_id_prefix": .string(currentUserID.diagnosticsPrefix),
                        "reason": "missing_response_data",
                        "api_code": .string(response.code)
                    ]
                )
                return false
            }
            setState(.uploaded(upload))
            await Diagnostics.track(
                "pet.media_upload_succeeded",
                properties: [
                    "media_slot": .string(debugKind),
                    "user_id_prefix": .string(currentUserID.diagnosticsPrefix),
                    "asset_id_prefix": .string(upload.asset.id.diagnosticsPrefix),
                    "usage_kind": .string(upload.asset.usageKind.rawValue),
                    "mime_type": .string(upload.asset.mimeType),
                    "byte_size": .int(upload.asset.byteSize),
                    "width": .int(upload.asset.width ?? 0),
                    "height": .int(upload.asset.height ?? 0),
                    "derivative_count": .int(upload.derivatives.count),
                    "component_count": .int(upload.components.count),
                    "has_theme_color": .bool(upload.themeColorHex != nil),
                    "has_cover_frame": .bool(upload.coverFrame != nil)
                ]
            )
            return true
        } catch {
            setState(.failed(error.toastMessage))
            await Diagnostics.track(
                "pet.media_upload_failed",
                properties: [
                    "media_slot": .string(debugKind),
                    "user_id_prefix": .string(currentUserID.diagnosticsPrefix),
                    "byte_size": .int(draft.byteSize),
                    "error_kind": .string(error.diagnosticsKind)
                ]
            )
            return false
        }
    }
}

// PetMediaUploadSlotState 单个媒体槽位上传状态
// 核心职责：
// - 表达头像或背景的上传进度、成功资产和失败原因
// - 为页面禁用保存和遮罩展示提供稳定状态
enum PetMediaUploadSlotState: Equatable {
    case idle
    case uploading(progress: Double?)
    case uploaded(PetMediaUploadResult)
    case failed(String)

    var isUploading: Bool {
        if case .uploading = self {
            return true
        }
        return false
    }

    var progress: Double? {
        if case .uploading(let progress) = self {
            return progress
        }
        return nil
    }

    var assetID: String? {
        if case .uploaded(let result) = self {
            return result.asset.id
        }
        return nil
    }
}

private extension String {
    var diagnosticsPrefix: String {
        String(prefix(8))
    }
}

private extension MHBAPIError {
    var diagnosticsKind: String {
        switch self {
        case .transport:
            "transport"
        case .business(let code, _, let statusCode):
            "business:\(code):\(statusCode)"
        case .decoding:
            "decoding"
        case .invalidResponse:
            "invalid_response"
        }
    }
}
