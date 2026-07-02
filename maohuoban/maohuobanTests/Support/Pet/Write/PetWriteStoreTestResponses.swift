@testable import maohuoban

// PetWriteStoreTests 测试响应构造
// 核心职责：
// - 提供宠物写入 Store 测试使用的固定响应
// - 让测试用例保持聚焦于状态流断言
@MainActor
extension PetWriteStoreTests {
    static func mediaUploadResponse(
        usageKind: PetMediaUsageKind
    ) -> MHBAPIResponse<PetMediaUploadResult> {
        MHBAPIResponse(
            success: true,
            code: "pet.media_uploaded",
            message: "媒体已上传",
            data: PetMediaUploadResult(
                asset: PetMediaAsset(
                    id: "asset-1",
                    uploadedByUserID: "user-1",
                    ownerPetID: "pet-1",
                    usageKind: usageKind,
                    sourceClient: "ios",
                    originalFileName: "media",
                    mimeType: "image/jpeg",
                    byteSize: 16,
                    sha256Hex: "hash",
                    bucket: "maohuoban-pet-media",
                    objectKey: "pets/pet-1/media",
                    status: .bound,
                    width: 1280,
                    height: 720,
                    createdAt: "2026-06-17T00:00:00Z",
                    updatedAt: "2026-06-17T00:00:00Z"
                ),
                binding: PetMediaBinding(
                    id: "binding-1",
                    assetID: "asset-1",
                    petID: "pet-1",
                    usageKind: usageKind,
                    status: .active,
                    boundByUserID: "user-1",
                    boundAt: "2026-06-17T00:00:00Z",
                    createdAt: "2026-06-17T00:00:00Z"
                ),
                derivatives: [
                    PetMediaDerivative(
                        id: "derivative-cover",
                        parentAssetID: "asset-1",
                        derivativeKind: .videoCoverFrame,
                        bucket: "maohuoban-pet-media",
                        objectKey: "pets/pet-1/cover-frame.png",
                        mimeType: "image/png",
                        byteSize: 12,
                        sha256Hex: "hash",
                        metadata: PetMediaDerivativeMetadata(width: 512, height: 512),
                        createdAt: "2026-06-17T00:00:00Z"
                    ),
                    PetMediaDerivative(
                        id: "derivative-theme",
                        parentAssetID: "asset-1",
                        derivativeKind: .themeColorFrame,
                        bucket: "maohuoban-pet-media",
                        objectKey: "pets/pet-1/theme-color.json",
                        mimeType: "application/json",
                        byteSize: 24,
                        sha256Hex: "hash",
                        metadata: PetMediaDerivativeMetadata(themeColorHex: "#FF0000"),
                        createdAt: "2026-06-17T00:00:00Z"
                    )
                ].filter { derivative in
                    usageKind == .backgroundVideo || derivative.derivativeKind == .themeColorFrame
                }
            )
        )
    }

    static func createPetResponse() -> MHBAPIResponse<PetProfileSummary> {
        MHBAPIResponse(
            success: true,
            code: "pet.created",
            message: "宠物档案已创建",
            data: PetProfileSummary(
                id: "pet-1",
                ownerUserID: "user-1",
                name: "糯米",
                species: .dog,
                breed: nil,
                sex: .unknown,
                birthday: nil
            )
        )
    }
}
