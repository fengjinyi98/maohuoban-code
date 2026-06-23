import Foundation
import MaohuobanDiagnostics

// PetMediaUploadStore 实况照片上传命令
// 核心职责：
// - 处理背景实况照片的成对媒体上传
// - 维护实况照片上传进度、成功结果和失败提示
extension PetMediaUploadStore {
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

    private func uploadPendingLivePhoto(
        debugKind: String,
        draft: PetLivePhotoUploadDraft,
        currentUserID: String?,
        setState: @escaping (PetMediaUploadSlotState) -> Void,
        perform: (
            PetLivePhotoUploadDraft,
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
