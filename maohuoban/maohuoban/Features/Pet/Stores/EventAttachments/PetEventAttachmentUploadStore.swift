import Observation
import UIKit

// PetEventAttachmentUploadStore 事件附件上传状态模型
// 核心职责：
// - 管理喂食与异常记录附件的即时上传流程
// - 向事件保存链路暴露已上传成功的资产 ID 列表
@MainActor
@Observable
final class PetEventAttachmentUploadStore {
    static let maxAttachmentCount = 3

    private(set) var attachments: [PetEventAttachmentDraft] = []

    let repository: PetRepository

    init(repository: PetRepository = DefaultPetRepository()) {
        self.repository = repository
    }

    var uploadedAssetIDs: [String] {
        attachments.compactMap { attachment in
            guard case .uploaded = attachment.uploadState else { return nil }
            return attachment.assetID
        }
    }

    var isUploading: Bool {
        attachments.contains { $0.uploadState.isUploading }
    }

    var hasFailedUploads: Bool {
        attachments.contains { $0.uploadState.isFailed }
    }

    var canAddMore: Bool {
        attachments.count < Self.maxAttachmentCount
    }

    var remainingSelectionCount: Int {
        max(0, Self.maxAttachmentCount - attachments.count)
    }

    func uploadPickedImages(
        _ images: [UIImage],
        localIdentifiers: [String?],
        currentUserID: String?
    ) async {
        let selectedImages = Array(images.prefix(remainingSelectionCount))
        guard !selectedImages.isEmpty else { return }

        let startIndex = attachments.count
        let newAttachments = selectedImages.enumerated().map { offset, image in
            let localIdentifier = localIdentifiers.indices.contains(offset) ? localIdentifiers[offset] : nil
            return PetEventAttachmentDraft(
                localIdentifier: localIdentifier,
                previewImage: image,
                uploadState: .uploading(progress: 0)
            )
        }
        attachments.append(contentsOf: newAttachments)

        for (offset, attachment) in newAttachments.enumerated() {
            await uploadAttachment(
                id: attachment.id,
                image: attachment.previewImage,
                index: startIndex + offset,
                currentUserID: currentUserID
            )
        }
    }

    func removeAttachment(id: UUID) {
        attachments.removeAll { $0.id == id }
    }

    func retryAttachment(id: UUID, currentUserID: String?) async {
        guard let index = attachments.firstIndex(where: { $0.id == id }) else { return }
        let image = attachments[index].previewImage
        attachments[index].assetID = nil
        attachments[index].remoteURLString = nil
        attachments[index].uploadState = .uploading(progress: 0)
        await uploadAttachment(
            id: id,
            image: image,
            index: index,
            currentUserID: currentUserID
        )
    }

    private func uploadAttachment(
        id: UUID,
        image: UIImage,
        index: Int,
        currentUserID: String?
    ) async {
        guard let currentUserID, !currentUserID.isEmpty else {
            markFailed(id: id, message: "请先登录")
            return
        }
        guard let draft = PetEventAttachmentUploadDraftFactory.makeDraft(from: image, index: index) else {
            markFailed(id: id, message: "照片编码失败")
            return
        }

        do {
            let response = try await repository.uploadEventAttachment(
                draft: draft,
                currentUserID: currentUserID
            ) { [weak self] progress in
                self?.updateState(id: id, uploadState: .uploading(progress: progress))
            }
            guard let upload = response.data else {
                markFailed(id: id, message: "媒体数据为空")
                return
            }
            guard let remoteURLString = upload.asset.url, !remoteURLString.isEmpty else {
                markFailed(id: id, message: "媒体地址为空")
                return
            }
            markUploaded(id: id, assetID: upload.asset.id, remoteURLString: remoteURLString)
        } catch {
            markFailed(id: id, message: error.toastMessage)
        }
    }

    private func updateState(id: UUID, uploadState: PetEventAttachmentUploadState) {
        guard let index = attachments.firstIndex(where: { $0.id == id }) else { return }
        attachments[index].uploadState = uploadState
    }

    private func markUploaded(id: UUID, assetID: String, remoteURLString: String) {
        guard let index = attachments.firstIndex(where: { $0.id == id }) else { return }
        attachments[index].assetID = assetID
        attachments[index].remoteURLString = remoteURLString
        attachments[index].uploadState = .uploaded
    }

    private func markFailed(id: UUID, message: String) {
        guard let index = attachments.firstIndex(where: { $0.id == id }) else { return }
        attachments[index].uploadState = .failed(message)
    }
}
