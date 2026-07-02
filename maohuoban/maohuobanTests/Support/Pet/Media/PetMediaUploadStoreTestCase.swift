import Foundation
import XCTest
import MaohuobanDiagnostics
@testable import maohuoban

// PetMediaUploadStoreTestCase 宠物媒体上传 Store 测试基类
// 核心职责：
// - 提供媒体上传 Store 测试固定响应
// - 统一清理诊断运行时
@MainActor
class PetMediaUploadStoreTestCase: XCTestCase {
    override func tearDown() {
        Task {
            await Diagnostics.uninstall()
        }
        super.tearDown()
    }

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
                    ownerPetID: nil,
                    usageKind: usageKind,
                    sourceClient: "ios",
                    originalFileName: "media",
                    mimeType: "image/jpeg",
                    byteSize: 16,
                    sha256Hex: "hash",
                    bucket: "maohuoban-pet-media",
                    objectKey: "pet-media/media",
                    status: .uploaded,
                    width: 1280,
                    height: 720,
                    createdAt: "2026-06-17T00:00:00Z",
                    updatedAt: "2026-06-17T00:00:00Z"
                ),
                binding: nil
            )
        )
    }

    static func installDiagnostics() async throws -> DiagnosticsRuntime {
        await Diagnostics.uninstall()
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("maohuoban-media-upload-tests-\(UUID().uuidString)", isDirectory: true)
        return try await Diagnostics.install(
            DiagnosticsConfiguration(
                serviceName: "maohuoban-ios-tests",
                environment: "test",
                storageDirectory: root
            )
        )
    }
}
