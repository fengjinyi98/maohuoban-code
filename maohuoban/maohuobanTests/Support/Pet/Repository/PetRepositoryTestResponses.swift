import Foundation
@testable import maohuoban

// PetRepositoryTestResponses 宠物仓库测试响应构造
// 核心职责：
// - 提供媒体仓库契约测试使用的固定响应 JSON
// - 保持测试基类聚焦于请求桩与通用断言
@MainActor
extension PetRepositoryTestCase {
    static func mediaUploadResponse(
        usageKind: String,
        objectKey: String
    ) -> (HTTPURLResponse, Data) {
        jsonResponse(
            statusCode: 201,
            body:
            """
            {
              "success": true,
              "code": "pet.background_uploaded",
              "message": "宠物背景已上传",
              "data": {
                "asset": {
                  "id": "asset-1",
                  "uploaded_by_user_id": "user-1",
                  "owner_pet_id": "pet-1",
                  "usage_kind": "\(usageKind)",
                  "source_client": "ios",
                  "original_file_name": "background",
                  "mime_type": "application/octet-stream",
                  "byte_size": 12,
                  "sha256_hex": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
                  "bucket": "maohuoban-pet-media",
                  "object_key": "\(objectKey)",
                  "status": "bound",
                  "width": 1280,
                  "height": 720,
                  "created_at": "2026-06-17T00:00:00Z",
                  "updated_at": "2026-06-17T00:00:00Z"
                },
                "binding": {
                  "id": "binding-1",
                  "asset_id": "asset-1",
                  "pet_id": "pet-1",
                  "usage_kind": "\(usageKind)",
                  "status": "active",
                  "bound_by_user_id": "user-1",
                  "bound_at": "2026-06-17T00:00:00Z",
                  "created_at": "2026-06-17T00:00:00Z"
                },
                "derivatives": [
                  {
                    "id": "derivative-1",
                    "parent_asset_id": "asset-1",
                    "derivative_kind": "video_cover_frame",
                    "bucket": "maohuoban-pet-media",
                    "object_key": "pets/pet-1/cover-frame.png",
                    "mime_type": "image/png",
                    "byte_size": 12,
                    "sha256_hex": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
                    "metadata": {
                      "width": 512,
                      "height": 512
                    },
                    "created_at": "2026-06-17T00:00:00Z"
                  },
                  {
                    "id": "derivative-2",
                    "parent_asset_id": "asset-1",
                    "derivative_kind": "theme_color_frame",
                    "bucket": "maohuoban-pet-media",
                    "object_key": "pets/pet-1/theme-color.json",
                    "mime_type": "application/json",
                    "byte_size": 24,
                    "sha256_hex": "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc",
                    "metadata": {
                      "theme_color_hex": "#FF0000"
                    },
                    "created_at": "2026-06-17T00:00:00Z"
                  }
                ]
              }
            }
            """
        )
    }

    static func pendingMediaUploadResponse(
        usageKind: String,
        objectKey: String
    ) -> (HTTPURLResponse, Data) {
        jsonResponse(
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
                  "usage_kind": "\(usageKind)",
                  "source_client": "ios",
                  "original_file_name": "background",
                  "mime_type": "application/octet-stream",
                  "byte_size": 12,
                  "sha256_hex": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
                  "bucket": "maohuoban-pet-media",
                  "object_key": "\(objectKey)",
                  "status": "uploaded",
                  "width": 1280,
                  "height": 720,
                  "created_at": "2026-06-17T00:00:00Z",
                  "updated_at": "2026-06-17T00:00:00Z"
                },
                "binding": null,
                "derivatives": [
                  {
                    "id": "derivative-1",
                    "parent_asset_id": "asset-1",
                    "derivative_kind": "video_cover_frame",
                    "bucket": "maohuoban-pet-media",
                    "object_key": "pets/pet-1/cover-frame.png",
                    "mime_type": "image/png",
                    "byte_size": 12,
                    "sha256_hex": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
                    "metadata": {
                      "width": 512,
                      "height": 512
                    },
                    "created_at": "2026-06-17T00:00:00Z"
                  },
                  {
                    "id": "derivative-2",
                    "parent_asset_id": "asset-1",
                    "derivative_kind": "theme_color_frame",
                    "bucket": "maohuoban-pet-media",
                    "object_key": "pets/pet-1/theme-color.json",
                    "mime_type": "application/json",
                    "byte_size": 24,
                    "sha256_hex": "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc",
                    "metadata": {
                      "theme_color_hex": "#FF0000"
                    },
                    "created_at": "2026-06-17T00:00:00Z"
                  }
                ]
              }
            }
            """
        )
    }

    static func pendingLivePhotoUploadResponse() -> (HTTPURLResponse, Data) {
        jsonResponse(
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
                  "url": null,
                  "uploaded_by_user_id": "user-1",
                  "owner_pet_id": null,
                  "usage_kind": "pet.background.live_photo",
                  "source_client": "ios",
                  "original_file_name": "background.heic",
                  "mime_type": "image/heic",
                  "byte_size": 32,
                  "sha256_hex": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
                  "bucket": "maohuoban-pet-media",
                  "object_key": "pet-media/pet/background/live-photo/asset-1/background.heic",
                  "status": "uploaded",
                  "width": 1200,
                  "height": 1600,
                  "created_at": "2026-06-17T00:00:00Z",
                  "updated_at": "2026-06-17T00:00:00Z"
                },
                "binding": null,
                "components": [
                  {
                    "id": "component-still",
                    "asset_id": "asset-1",
                    "url": "/api/v1/media/assets/asset-1/components/component-still/content",
                    "component_kind": "still",
                    "bucket": "maohuoban-pet-media",
                    "object_key": "pet-media/pet/background/live-photo/asset-1/still.heic",
                    "mime_type": "image/heic",
                    "byte_size": 12,
                    "sha256_hex": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
                    "width": 1200,
                    "height": 1600,
                    "duration_ms": null,
                    "created_at": "2026-06-17T00:00:00Z"
                  },
                  {
                    "id": "component-video",
                    "asset_id": "asset-1",
                    "url": "/api/v1/media/assets/asset-1/components/component-video/content",
                    "component_kind": "paired_video",
                    "bucket": "maohuoban-pet-media",
                    "object_key": "pet-media/pet/background/live-photo/asset-1/paired.mov",
                    "mime_type": "video/quicktime",
                    "byte_size": 20,
                    "sha256_hex": "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc",
                    "width": 1200,
                    "height": 1600,
                    "duration_ms": 1800,
                    "created_at": "2026-06-17T00:00:00Z"
                  }
                ],
                "derivatives": []
              }
            }
            """
        )
    }
}
