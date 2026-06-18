import XCTest
import MaohuobanDiagnostics
@testable import maohuoban

// PetMediaUploadDiagnosticsTests 宠物媒体上传诊断测试
// 核心职责：
// - 验证媒体上传成功写入诊断事件
// - 验证媒体绑定成功写入诊断事件
@MainActor
final class PetMediaUploadDiagnosticsTests: PetMediaUploadStoreTestCase {
    func testUploadBackgroundVideoRecordsDiagnosticsEvents() async throws {
        let diagnostics = try await Self.installDiagnostics()
        let repository = CapturingPetMediaUploadRepository()
        repository.uploadPendingBackgroundVideoResult = .success(Self.mediaUploadResponse(usageKind: .backgroundVideo))
        let store = PetMediaUploadStore(repository: repository)

        let didUpload = await store.uploadBackgroundVideo(
            draft: PetMediaUploadDraft(
                fileName: "background.mov",
                mimeType: "video/mp4",
                content: Data("video-content".utf8),
                sourceClient: "ios"
            ),
            currentUserID: "user-1"
        )

        XCTAssertTrue(didUpload)
        let events = try await diagnostics.readEvents()
        XCTAssertTrue(events.contains {
            $0.kind == .analytics
                && $0.message == "pet.media_upload_started"
                && $0.metadata["media_slot"] == "backgroundVideo"
                && $0.metadata["mime_type"] == "video/mp4"
        })
        XCTAssertTrue(events.contains {
            $0.kind == .analytics
                && $0.message == "pet.media_upload_succeeded"
                && $0.metadata["media_slot"] == "backgroundVideo"
                && $0.metadata["asset_id_prefix"] == "asset-1"
                && $0.metadata["width"] == 1280
                && $0.metadata["height"] == 720
        })
    }

    func testBindUploadedMediaRecordsDiagnosticsEvent() async throws {
        let diagnostics = try await Self.installDiagnostics()
        let repository = CapturingPetMediaUploadRepository()
        repository.bindUploadedMediaResult = .success(Self.mediaUploadResponse(usageKind: .backgroundImage))
        let store = PetMediaUploadStore(repository: repository)

        let didBind = await store.bindUploadedMedia(
            petID: "pet-1",
            assetID: "asset-1",
            currentUserID: "user-1"
        )

        XCTAssertTrue(didBind)
        let events = try await diagnostics.readEvents()
        XCTAssertTrue(events.contains {
            $0.kind == .analytics
                && $0.message == "pet.media_bind_succeeded"
                && $0.metadata["pet_id_prefix"] == "pet-1"
                && $0.metadata["asset_id_prefix"] == "asset-1"
        })
    }
}
