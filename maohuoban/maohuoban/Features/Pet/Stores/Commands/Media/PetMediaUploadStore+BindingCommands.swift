import MaohuobanDiagnostics

// PetMediaUploadStore 绑定命令
// 核心职责：
// - 将已上传媒体资产绑定到宠物档案
// - 记录绑定结果诊断事件
extension PetMediaUploadStore {
    func bindUploadedMedia(
        petID: String,
        assetID: String,
        currentUserID: String?
    ) async -> Bool {
        guard let currentUserID, !currentUserID.isEmpty else {
            await Diagnostics.track(
                "pet.media_bind_rejected",
                properties: [
                    "reason": "missing_user",
                    "pet_id_prefix": .string(petID.diagnosticsPrefix),
                    "asset_id_prefix": .string(assetID.diagnosticsPrefix)
                ]
            )
            return false
        }
        do {
            let response = try await repository.bindUploadedMedia(
                petID: petID,
                assetID: assetID,
                currentUserID: currentUserID
            )
            await Diagnostics.track(
                "pet.media_bind_succeeded",
                properties: [
                    "pet_id_prefix": .string(petID.diagnosticsPrefix),
                    "asset_id_prefix": .string(assetID.diagnosticsPrefix),
                    "user_id_prefix": .string(currentUserID.diagnosticsPrefix),
                    "usage_kind": .string(response.data?.asset.usageKind.rawValue ?? ""),
                    "has_binding": .bool(response.data?.binding != nil)
                ]
            )
            return true
        } catch {
            await Diagnostics.track(
                "pet.media_bind_failed",
                properties: [
                    "pet_id_prefix": .string(petID.diagnosticsPrefix),
                    "asset_id_prefix": .string(assetID.diagnosticsPrefix),
                    "user_id_prefix": .string(currentUserID.diagnosticsPrefix),
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
