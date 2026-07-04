import Foundation

// PetMediaUploadResult 宠物媒体上传结果
// 核心职责：
// - 承接媒体资产元数据
// - 承接当前有效业务绑定
struct PetMediaUploadResult: Decodable, Equatable {
    let asset: PetMediaAsset
    let binding: PetMediaBinding?
    let derivatives: [PetMediaDerivative]
    let components: [PetMediaAssetComponent]

    var themeColorHex: String? {
        derivatives.compactMap(\.metadata.themeColorHex).first
    }

    var coverFrame: PetMediaDerivative? {
        derivatives.first { $0.derivativeKind == .videoCoverFrame }
    }

    var derivativeStatusMessage: String? {
        guard !derivatives.isEmpty else {
            switch asset.usageKind {
            case .backgroundImage, .backgroundVideo, .backgroundLivePhoto:
                return "派生资源处理中"
            case .avatar, .albumPhoto, .foodInventoryCover:
                return nil
            }
        }

        let resourceText = "\(derivatives.count) 个派生资源"
        switch (coverFrame != nil, themeColorHex) {
        case (true, let themeColor?):
            return "已生成封面帧、主题色 \(themeColor) 和 \(resourceText)"
        case (true, nil):
            return "已生成封面帧和 \(resourceText)"
        case (false, let themeColor?):
            return "已生成主题色 \(themeColor) 和 \(resourceText)"
        case (false, nil):
            return "已生成 \(resourceText)"
        }
    }

    enum CodingKeys: String, CodingKey {
        case asset
        case binding
        case derivatives
        case components
    }

    init(
        asset: PetMediaAsset,
        binding: PetMediaBinding?,
        derivatives: [PetMediaDerivative] = [],
        components: [PetMediaAssetComponent] = []
    ) {
        self.asset = asset
        self.binding = binding
        self.derivatives = derivatives
        self.components = components
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        asset = try container.decode(PetMediaAsset.self, forKey: .asset)
        binding = try container.decodeIfPresent(PetMediaBinding.self, forKey: .binding)
        derivatives = try container.decodeIfPresent([PetMediaDerivative].self, forKey: .derivatives) ?? []
        components = try container.decodeIfPresent([PetMediaAssetComponent].self, forKey: .components) ?? []
    }
}
