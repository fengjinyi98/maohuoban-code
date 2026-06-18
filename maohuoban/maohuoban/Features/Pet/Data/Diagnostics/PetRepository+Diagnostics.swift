import Foundation
import MaohuobanDiagnostics

extension DefaultPetRepository {
    // recordPetDraftPrepared 记录宠物档案写入草稿摘要
    // 核心职责：
    // - 保留品种字段是否进入请求前链路
    // - 避免采集真实宠物品种文本
    func recordPetDraftPrepared(
        eventName: String,
        draftBreed: String,
        currentUserID: String,
        metadata: DiagnosticProperties = [:]
    ) async {
        let normalizedBreedLength = draftBreed.filter { !$0.isWhitespace }.count
        await Diagnostics.track(
            eventName,
            properties: metadata.merging([
                "user_id_prefix": .string(diagnosticsPrefix(currentUserID)),
                "breed_length_non_whitespace": .int(normalizedBreedLength),
                "breed_is_empty": .bool(normalizedBreedLength == 0)
            ]) { _, new in new }
        )
    }

    // recordPetProfileResponse 记录宠物档案响应摘要
    // 核心职责：
    // - 判断后端响应是否携带品种和媒体字段
    // - 为首页和编辑页消费问题提供统一事件
    func recordPetProfileResponse(
        eventName: String,
        response: MHBAPIResponse<PetProfileSummary>,
        currentUserID: String,
        metadata: DiagnosticProperties = [:]
    ) async {
        let responseBreedLength = response.data?.breed?.filter { !$0.isWhitespace }.count ?? 0
        await Diagnostics.track(
            eventName,
            properties: metadata.merging([
                "user_id_prefix": .string(diagnosticsPrefix(currentUserID)),
                "api_code": .string(response.code),
                "has_pet": .bool(response.data != nil),
                "pet_id_prefix": .string(diagnosticsPrefix(response.data?.id)),
                "breed_present": .bool(response.data?.breed != nil),
                "breed_length_non_whitespace": .int(responseBreedLength),
                "background_asset_id_prefix": .string(diagnosticsPrefix(response.data?.backgroundAssetID)),
                "background_media_kind": .string(response.data?.backgroundMediaKind?.rawValue ?? "")
            ]) { _, new in new }
        )
    }

    // recordMediaResponse 记录宠物媒体响应摘要
    // 核心职责：
    // - 保留媒体资产尺寸、用途、状态和派生物数量
    // - 支撑视频上传、绑定和首页展示链路排查
    func recordMediaResponse(
        eventName: String,
        response: MHBAPIResponse<PetMediaUploadResult>,
        currentUserID: String,
        metadata: DiagnosticProperties = [:]
    ) async {
        let asset = response.data?.asset
        await Diagnostics.track(
            eventName,
            properties: metadata.merging([
                "user_id_prefix": .string(diagnosticsPrefix(currentUserID)),
                "api_code": .string(response.code),
                "has_asset": .bool(asset != nil),
                "asset_id_prefix": .string(diagnosticsPrefix(asset?.id)),
                "usage_kind": .string(asset?.usageKind.rawValue ?? ""),
                "mime_type": .string(asset?.mimeType ?? ""),
                "byte_size": .int(asset?.byteSize ?? 0),
                "width": .int(asset?.width ?? 0),
                "height": .int(asset?.height ?? 0),
                "asset_status": .string(asset?.status.rawValue ?? ""),
                "has_binding": .bool(response.data?.binding != nil),
                "derivative_count": .int(response.data?.derivatives.count ?? 0),
                "has_theme_color": .bool(response.data?.themeColorHex != nil),
                "has_cover_frame": .bool(response.data?.coverFrame != nil)
            ]) { _, new in new }
        )
    }

    // recordPetFailure 记录宠物写入失败摘要
    // 核心职责：
    // - 统一记录失败类型和用户前缀
    // - 避免把可展示 toast 文案当作诊断主键
    func recordPetFailure(
        eventName: String,
        error: MHBAPIError,
        currentUserID: String,
        metadata: DiagnosticProperties = [:]
    ) async {
        await Diagnostics.track(
            eventName,
            properties: metadata.merging([
                "user_id_prefix": .string(diagnosticsPrefix(currentUserID)),
                "error_kind": .string(error.diagnosticsKind)
            ]) { _, new in new }
        )
    }
}

extension DefaultPetRepository {
    func diagnosticsPrefix(_ value: String?) -> String {
        guard let value else {
            return ""
        }
        return String(value.prefix(8))
    }

    func diagnosticsPrefix(_ value: String) -> String {
        String(value.prefix(8))
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
