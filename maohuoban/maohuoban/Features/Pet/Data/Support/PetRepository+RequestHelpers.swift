import Foundation

extension DefaultPetRepository {
    func userHeaders(currentUserID: String) throws(MHBAPIError) -> [String: String] {
        guard !currentUserID.isEmpty else {
            throw .business(
                code: "auth.session_expired",
                message: "登录状态已过期，请重新登录",
                statusCode: 401
            )
        }
        return try authorizationHeaderProvider.headers()
    }

    func multipartFile(from draft: PetMediaUploadDraft) -> MHBMultipartFile {
        MHBMultipartFile(
            fieldName: "file",
            fileName: draft.fileName,
            mimeType: draft.mimeType,
            data: draft.content
        )
    }

    func multipartFields(from draft: PetMediaUploadDraft) -> [String: String] {
        ["source_client": draft.sourceClient]
    }

    func multipartFiles(from draft: PetLivePhotoUploadDraft) -> [MHBMultipartFile] {
        [
            MHBMultipartFile(
                fieldName: "still_file",
                fileName: draft.still.fileName,
                mimeType: draft.still.mimeType,
                data: draft.still.content
            ),
            MHBMultipartFile(
                fieldName: "paired_video_file",
                fileName: draft.pairedVideo.fileName,
                mimeType: draft.pairedVideo.mimeType,
                data: draft.pairedVideo.content
            )
        ]
    }

    func multipartFields(from draft: PetLivePhotoUploadDraft) -> [String: String] {
        var fields = ["source_client": draft.sourceClient]
        if let cropMetadata = draft.cropMetadata {
            fields["crop_x"] = String(cropMetadata.x)
            fields["crop_y"] = String(cropMetadata.y)
            fields["crop_width"] = String(cropMetadata.width)
            fields["crop_height"] = String(cropMetadata.height)
        }
        return fields
    }
}
