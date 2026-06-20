import SwiftUI
import MaohuobanDesignSystem

// PetAlbumMosaicGrid 相册详情马赛克照片墙
// 核心职责：
// - 按固定 7 张一组的视觉节奏呈现照片墙
// - 使用 LazyVStack 分组渲染降低长列表首屏压力
struct PetAlbumMosaicGrid: View {
    let assets: [PetAlbumAsset]

    private let clusterSize = 7

    var body: some View {
        LazyVStack(spacing: MHBTheme.Spacing.s2) {
            ForEach(clusters) { cluster in
                PetAlbumMosaicCluster(assets: cluster.assets)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("petAlbum.detail.mosaicGrid")
    }

    private var clusters: [PetAlbumMosaicClusterData] {
        stride(from: 0, to: assets.count, by: clusterSize).map { startIndex in
            let endIndex = min(startIndex + clusterSize, assets.count)
            let clusterAssets = Array(assets[startIndex..<endIndex])
            return PetAlbumMosaicClusterData(id: clusterAssets.first?.id ?? "empty-\(startIndex)", assets: clusterAssets)
        }
    }
}

// PetAlbumMosaicClusterData 照片墙分组数据
// 核心职责：
// - 为 LazyVStack 中的每个马赛克分组提供稳定身份
// - 持有当前分组需要布局的照片集合
private struct PetAlbumMosaicClusterData: Identifiable {
    let id: String
    let assets: [PetAlbumAsset]
}

// PetAlbumMosaicCluster 单组马赛克布局
// 核心职责：
// - 按设计稿的大图、横图和竖图节奏摆放单组图片
// - 将布局计算限制为当前分组的纯几何计算
private struct PetAlbumMosaicCluster: View {
    let assets: [PetAlbumAsset]

    var body: some View {
        GeometryReader { proxy in
            let frames = PetAlbumMosaicFramePlan.frames(
                itemCount: assets.count,
                containerWidth: proxy.size.width,
                spacing: MHBTheme.Spacing.s2
            )

            ZStack(alignment: .topLeading) {
                ForEach(assets.enumerated(), id: \.element.id) { index, asset in
                    if frames.indices.contains(index) {
                        PetAlbumMosaicTile(asset: asset)
                            .frame(width: frames[index].width, height: frames[index].height)
                            .offset(x: frames[index].minX, y: frames[index].minY)
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
        .aspectRatio(PetAlbumMosaicFramePlan.clusterAspectRatio, contentMode: .fit)
    }
}

// PetAlbumMosaicTile 照片墙单图
// 核心职责：
// - 渲染单张图片及设计稿中的内描边
// - 提供图片来源与说明的无障碍描述
private struct PetAlbumMosaicTile: View {
    let asset: PetAlbumAsset

    var body: some View {
        PetAlbumAssetImage(imageAssetName: asset.imageAssetName)
            .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous)
                    .strokeBorder(MHBTheme.ColorToken.labelPrimary.color.opacity(0.12), lineWidth: 3)
            }
            .overlay {
                RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous)
                    .strokeBorder(MHBTheme.ColorToken.separator.color, lineWidth: 1)
            }
            .clipped()
            .accessibilityLabel(asset.caption ?? sourceAccessibilityText)
    }

    private var sourceAccessibilityText: String {
        switch asset.source {
        case .userUpload:
            return "用户上传照片"
        case .ugcLinked:
            return "来自图文内容的相册照片"
        case .ugcDetached:
            return "已从图文内容保留到相册的照片"
        }
    }
}

// PetAlbumMosaicFramePlan 马赛克布局计算
// 核心职责：
// - 根据容器宽度计算单组图片 frame
// - 保持布局函数纯计算，便于后续接入真实图片尺寸策略
private enum PetAlbumMosaicFramePlan {
    static let clusterAspectRatio: CGFloat = 0.72

    static func frames(
        itemCount: Int,
        containerWidth: CGFloat,
        spacing: CGFloat
    ) -> [CGRect] {
        let column = max((containerWidth - spacing * 2) / 3, 1)
        let one = column
        let two = column * 2 + spacing

        let pattern = [
            CGRect(x: 0, y: 0, width: two, height: two),
            CGRect(x: two + spacing, y: 0, width: one, height: one),
            CGRect(x: two + spacing, y: one + spacing, width: one, height: one),
            CGRect(x: 0, y: two + spacing, width: one, height: one),
            CGRect(x: one + spacing, y: two + spacing, width: two, height: one),
            CGRect(x: 0, y: two + one + spacing * 2, width: two, height: one),
            CGRect(x: two + spacing, y: two + one + spacing * 2, width: one, height: one)
        ]

        return Array(pattern.prefix(itemCount))
    }
}
