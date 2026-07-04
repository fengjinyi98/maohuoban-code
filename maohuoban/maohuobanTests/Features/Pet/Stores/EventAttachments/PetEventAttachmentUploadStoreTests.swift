import XCTest
import UIKit
@testable import maohuoban

// PetEventAttachmentUploadStoreTests 事件附件上传状态测试
// 核心职责：
// - 固化喂食与异常记录最多三张照片的上传约束
// - 验证选择后即时上传并暴露已上传资产 ID
@MainActor
final class PetEventAttachmentUploadStoreTests: PetMediaUploadStoreTestCase {
    func testUploadPickedImagesCapsSelectionAtThreeAndExposesUploadedAssetIDs() async {
        let repository = CapturingPetMediaUploadRepository()
        repository.uploadEventAttachmentResult = .success(
            Self.eventAttachmentUploadResponse()
        )
        let store = PetEventAttachmentUploadStore(repository: repository)

        await store.uploadPickedImages(
            [
                Self.makeImage(color: .red),
                Self.makeImage(color: .green),
                Self.makeImage(color: .blue),
                Self.makeImage(color: .orange)
            ],
            localIdentifiers: ["local-1", "local-2", "local-3", "local-4"],
            currentUserID: "user-1"
        )

        XCTAssertEqual(store.attachments.count, 3)
        XCTAssertFalse(store.canAddMore)
        XCTAssertEqual(store.uploadedAssetIDs, ["asset-1", "asset-1", "asset-1"])
        XCTAssertEqual(
            repository.callOrder.filter { $0 == "uploadEventAttachment" }.count,
            3
        )
        XCTAssertEqual(repository.receivedEventAttachmentUserID, "user-1")
    }
}

private extension PetEventAttachmentUploadStoreTests {
    static func eventAttachmentUploadResponse() -> MHBAPIResponse<PetMediaUploadResult> {
        MHBAPIResponse(
            success: true,
            code: "pet.media_uploaded",
            message: "媒体已上传",
            data: PetMediaUploadResult(
                asset: PetMediaAsset(
                    id: "asset-1",
                    url: "/api/v1/media/assets/asset-1/content",
                    uploadedByUserID: "user-1",
                    ownerPetID: nil,
                    usageKind: .eventAttachment,
                    sourceClient: "ios",
                    originalFileName: "event-attachment.jpg",
                    mimeType: "image/jpeg",
                    byteSize: 16,
                    sha256Hex: "hash",
                    bucket: "maohuoban-pet-media",
                    objectKey: "pet-media/event-attachment/asset-1/event-attachment.jpg",
                    status: .uploaded,
                    width: 8,
                    height: 8,
                    createdAt: "2026-07-04T00:00:00Z",
                    updatedAt: "2026-07-04T00:00:00Z"
                ),
                binding: nil
            )
        )
    }

    static func makeImage(color: UIColor) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8))
        return renderer.image { context in
            context.cgContext.setFillColor(color.cgColor)
            context.cgContext.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        }
    }
}
