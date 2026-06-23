import Foundation
import MaohuobanDiagnostics

// PetMediaUploadStore 单文件上传命令
// 核心职责：
// - 处理头像、背景图和背景视频上传
// - 维护上传进度、成功结果和失败提示
extension PetMediaUploadStore {
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

    private func uploadPendingMedia(
        debugKind: String,
        draft: PetMediaUploadDraft,
        currentUserID: String?,
        setState: @escaping (PetMediaUploadSlotState) -> Void,
        perform: (
            PetMediaUploadDraft,
            String,
            @escaping @MainActor @Sendable (Double) -> Void
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
