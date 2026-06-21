import Foundation
import XCTest
@testable import maohuoban

// PetRepositoryMediaContractTests 宠物媒体仓库契约测试
// 核心职责：
// - 验证待绑定媒体上传请求契约
// - 验证媒体绑定与派生资源响应解码
@MainActor
final class PetRepositoryMediaContractTests: PetRepositoryTestCase {
    func testUploadPendingAvatarSendsUserContextAndDecodesUnboundAssetURL() async throws {
        let repository = makeRepository { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/api/v1/pet-media/avatar")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-access-token")

            try Self.assertMultipartMediaRequest(
                request,
                fileName: "avatar.png",
                mimeType: "image/png",
                contentText: "avatar-bytes",
                sourceClient: "ios"
            )

            return Self.jsonResponse(
                statusCode: 201,
                body:
                """
                {
                  "success": true,
                  "code": "pet.media_uploaded",
                  "message": "媒体已上传",
                  "data": {
                    "asset": {
                      "id": "asset-1",
                      "url": "/api/v1/media/assets/asset-1/content",
                      "uploaded_by_user_id": "user-1",
                      "owner_pet_id": null,
                      "usage_kind": "pet.avatar",
                      "source_client": "ios",
                      "original_file_name": "avatar.png",
                      "mime_type": "image/png",
                      "byte_size": 12,
                      "sha256_hex": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
                      "bucket": "maohuoban-pet-media",
                      "object_key": "pet-media/pet/avatar/asset-1/avatar.png",
                      "status": "uploaded",
                      "width": 96,
                      "height": 96,
                      "created_at": "2026-06-17T00:00:00Z",
                      "updated_at": "2026-06-17T00:00:00Z"
                    },
                    "binding": null,
                    "derivatives": []
                  }
                }
                """
            )
        }

        let response = try await repository.uploadPendingAvatar(
            draft: PetMediaUploadDraft(
                fileName: "avatar.png",
                mimeType: "image/png",
                content: Data("avatar-bytes".utf8),
                sourceClient: "ios"
            ),
            currentUserID: "user-1"
        )

        XCTAssertEqual(response.message, "媒体已上传")
        XCTAssertEqual(response.data?.asset.id, "asset-1")
        XCTAssertEqual(response.data?.asset.url, "/api/v1/media/assets/asset-1/content")
        XCTAssertNil(response.data?.asset.ownerPetID)
        XCTAssertEqual(response.data?.asset.status, .uploaded)
        XCTAssertEqual(response.data?.asset.width, 96)
        XCTAssertEqual(response.data?.asset.height, 96)
        XCTAssertNil(response.data?.binding)
    }

    func testBindUploadedMediaSendsAssetIDAndDecodesMediaBinding() async throws {
        let repository = makeRepository { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/api/v1/pets/pet-1/media-bindings")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-access-token")

            let body = try XCTUnwrap(request.bodyDataForPetRepositoryTest())
            let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]
            XCTAssertEqual(json?["asset_id"] as? String, "asset-1")

            return Self.mediaUploadResponse(
                usageKind: "pet.avatar",
                objectKey: "pets/pet-1/pet/avatar/asset-1/avatar.png"
            )
        }

        let response = try await repository.bindUploadedMedia(
            petID: "pet-1",
            assetID: "asset-1",
            currentUserID: "user-1"
        )

        XCTAssertEqual(response.data?.asset.status, .bound)
        XCTAssertEqual(response.data?.binding?.petID, "pet-1")
    }

    func testUploadPendingBackgroundImageSendsUserContextAndDecodesUnboundAsset() async throws {
        let repository = makeRepository { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/api/v1/pet-media/background-image")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-access-token")
            try Self.assertMultipartMediaRequest(
                request,
                fileName: "background.jpg",
                mimeType: "image/jpeg",
                contentText: "image-bytes",
                sourceClient: "ios"
            )

            return Self.pendingMediaUploadResponse(
                usageKind: "pet.background.image",
                objectKey: "pet-media/pet/background/image/asset-1/background.jpg"
            )
        }

        let response = try await repository.uploadPendingBackgroundImage(
            draft: PetMediaUploadDraft(
                fileName: "background.jpg",
                mimeType: "image/jpeg",
                content: Data("image-bytes".utf8),
                sourceClient: "ios"
            ),
            currentUserID: "user-1"
        )

        XCTAssertEqual(response.message, "媒体已上传")
        XCTAssertEqual(response.data?.asset.usageKind, .backgroundImage)
        XCTAssertNil(response.data?.asset.ownerPetID)
        XCTAssertEqual(response.data?.asset.status, .uploaded)
        XCTAssertEqual(response.data?.asset.width, 1280)
        XCTAssertEqual(response.data?.asset.height, 720)
        XCTAssertNil(response.data?.binding)
        XCTAssertEqual(response.data?.derivatives.count, 2)
        XCTAssertEqual(response.data?.themeColorHex, "#FF0000")
    }

    func testUploadPendingBackgroundVideoSendsUserContextAndDecodesUnboundAsset() async throws {
        let repository = makeRepository { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/api/v1/pet-media/background-video")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-access-token")
            try Self.assertMultipartMediaRequest(
                request,
                fileName: "background.mp4",
                mimeType: "video/mp4",
                contentText: "video-bytes",
                sourceClient: "ios"
            )

            return Self.pendingMediaUploadResponse(
                usageKind: "pet.background.video",
                objectKey: "pet-media/pet/background/video/asset-1/background.mp4"
            )
        }

        let response = try await repository.uploadPendingBackgroundVideo(
            draft: PetMediaUploadDraft(
                fileName: "background.mp4",
                mimeType: "video/mp4",
                content: Data("video-bytes".utf8),
                sourceClient: "ios"
            ),
            currentUserID: "user-1"
        )

        XCTAssertEqual(response.message, "媒体已上传")
        XCTAssertEqual(response.data?.asset.usageKind, .backgroundVideo)
        XCTAssertNil(response.data?.asset.ownerPetID)
        XCTAssertEqual(response.data?.asset.status, .uploaded)
        XCTAssertEqual(response.data?.asset.width, 1280)
        XCTAssertEqual(response.data?.asset.height, 720)
        XCTAssertNil(response.data?.binding)
        XCTAssertEqual(response.data?.coverFrame?.objectKey, "pets/pet-1/cover-frame.png")
    }

    func testUploadPendingBackgroundLivePhotoSendsPairedResourcesAndDecodesComponents() async throws {
        let repository = makeRepository { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/api/v1/pet-media/background-live-photo")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-access-token")
            try Self.assertMultipartLivePhotoRequest(
                request,
                stillFileName: "background.heic",
                stillMimeType: "image/heic",
                stillContentText: "still-bytes",
                pairedVideoFileName: "background.mov",
                pairedVideoMimeType: "video/quicktime",
                pairedVideoContentText: "video-bytes",
                sourceClient: "ios",
                cropMetadata: MHBImageCropMetadata(
                    x: 0.125,
                    y: 0.25,
                    width: 0.5,
                    height: 0.375
                )
            )

            return Self.pendingLivePhotoUploadResponse()
        }

        let response = try await repository.uploadPendingBackgroundLivePhoto(
            draft: PetLivePhotoUploadDraft(
                still: PetMediaUploadDraft(
                    fileName: "background.heic",
                    mimeType: "image/heic",
                    content: Data("still-bytes".utf8),
                    sourceClient: "ios"
                ),
                pairedVideo: PetMediaUploadDraft(
                    fileName: "background.mov",
                    mimeType: "video/quicktime",
                    content: Data("video-bytes".utf8),
                    sourceClient: "ios"
                ),
                cropMetadata: MHBImageCropMetadata(
                    x: 0.125,
                    y: 0.25,
                    width: 0.5,
                    height: 0.375
                )
            ),
            currentUserID: "user-1"
        )

        XCTAssertEqual(response.message, "媒体已上传")
        XCTAssertEqual(response.data?.asset.usageKind, .backgroundLivePhoto)
        XCTAssertEqual(response.data?.components.count, 2)
        XCTAssertTrue(response.data?.components.contains { component in
            component.componentKind == .still
                && component.url == "/api/v1/media/assets/asset-1/components/component-still/content"
                && component.width == 1200
                && component.height == 1600
        } == true)
        XCTAssertTrue(response.data?.components.contains { component in
            component.componentKind == .pairedVideo
                && component.url == "/api/v1/media/assets/asset-1/components/component-video/content"
                && component.durationMS == 1800
        } == true)
    }
}
