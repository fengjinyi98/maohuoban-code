import SwiftUI
import MaohuobanDesignSystem

// PetWorldFeedDetailInterleavedArticle 图文混排详情正文
// 核心职责：
// - 按标题、作者、有序正文块顺序展示图文混排内容
// - 保持公开元信息、话题与推荐解释复用当前详情页展示组件
struct PetWorldFeedDetailInterleavedArticle: View {
    let galleryID: String
    let petName: String
    let petAvatarAssetName: String
    let authorName: String
    let publishedAt: Date
    let showsFollowButton: Bool
    let title: String
    let contentBlocks: [PetWorldFeedDetailContentBlock]
    let topics: [String]
    let visibleLocationName: String?
    let viewCount: Int
    let recommendationExplanation: String
    let showsRecommendationExplanation: Bool
    let onAuthorOffsetChange: (CGFloat) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s6) {
            Text(displayTitle)
                .font(MHBTheme.Typography.title)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .lineSpacing(MHBTheme.Spacing.s1)
                .fixedSize(horizontal: false, vertical: true)

            PetWorldFeedDetailAuthorSection(
                petName: petName,
                petAvatarAssetName: petAvatarAssetName,
                authorName: authorName,
                publishedAt: publishedAt,
                showsFollowButton: showsFollowButton,
                onOffsetChange: onAuthorOffsetChange
            )

            PetWorldFeedDetailInterleavedBlocks(
                galleryID: galleryID,
                contentBlocks: contentBlocks
            )

            PetWorldFeedDetailMetaLine(
                visibleLocationName: visibleLocationName,
                viewCount: viewCount
            )

            if !topics.isEmpty {
                PetWorldFeedDetailTopics(topics: topics)
            }

            if showsRecommendationExplanation {
                PetWorldFeedDetailRecommendationExplanation(text: recommendationExplanation)
            }
        }
    }

    private var displayTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// PetWorldFeedDetailInterleavedBlocks 图文混排内容块列表
// 核心职责：
// - 严格按发布顺序渲染段落和图片
// - 为内嵌图片提供同一组大图预览上下文
private struct PetWorldFeedDetailInterleavedBlocks: View {
    let galleryID: String
    let contentBlocks: [PetWorldFeedDetailContentBlock]

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s6) {
            ForEach(contentBlocks) { block in
                switch block {
                case let .paragraph(_, text):
                    PetWorldFeedDetailInterleavedParagraph(text: text)
                case let .image(id, media, caption):
                    PetWorldFeedDetailInterleavedImage(
                        galleryID: galleryID,
                        previewAssets: previewAssets,
                        index: imageIndexByBlockID[id] ?? 0,
                        media: media,
                        caption: caption
                    )
                }
            }
        }
    }

    private var previewAssets: [MHBImagePreviewAsset] {
        MHBImagePreviewAsset.localGallery(
            galleryID: galleryID,
            items: imageMediaItems.map { mediaItem in
                MHBImagePreviewAsset.LocalGalleryItem(
                    imageName: mediaItem.assetName,
                    pixelSize: mediaItem.pixelSize
                )
            }
        )
    }

    private var imageMediaItems: [PetWorldFeedDetailMedia] {
        contentBlocks.compactMap { block in
            guard case let .image(_, media, _) = block else {
                return nil
            }

            return media
        }
    }

    private var imageIndexByBlockID: [String: Int] {
        var indexes: [String: Int] = [:]
        var imageIndex = 0

        for block in contentBlocks {
            guard case let .image(id, _, _) = block else {
                continue
            }

            indexes[id] = imageIndex
            imageIndex += 1
        }

        return indexes
    }
}

// PetWorldFeedDetailInterleavedParagraph 图文混排段落
// 核心职责：
// - 展示用户发布时输入的正文段落
// - 使用适合长文阅读的行距和自然换行
private struct PetWorldFeedDetailInterleavedParagraph: View {
    let text: String

    var body: some View {
        Text(text)
            .font(MHBTheme.Typography.body)
            .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
            .lineSpacing(MHBTheme.Spacing.s2)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// PetWorldFeedDetailInterleavedImage 图文混排内嵌图片
// 核心职责：
// - 展示正文流中的单张图片和可选图片说明
// - 复用详情页大图预览能力
private struct PetWorldFeedDetailInterleavedImage: View {
    let galleryID: String
    let previewAssets: [MHBImagePreviewAsset]
    let index: Int
    let media: PetWorldFeedDetailMedia
    let caption: String?

    var body: some View {
        VStack(alignment: .center, spacing: MHBTheme.Spacing.s2) {
            MHBPreviewableImage(
                galleryID: galleryID,
                items: previewAssets,
                index: index,
                cornerRadius: PetWorldFeedDetailLayout.interleavedInlineImageCornerRadius,
                contentMode: .fill
            ) {
                MHBTheme.ColorToken.separatorSoft.color
            }
            .aspectRatio(imageAspectRatio, contentMode: .fit)
            .background(MHBTheme.ColorToken.separatorSoft.color)
            .clipShape(inlineImageShape)
            .shadow(
                color: MHBTheme.ColorToken.labelPrimary.color.opacity(
                    PetWorldFeedDetailLayout.interleavedInlineImageShadowOpacity
                ),
                radius: PetWorldFeedDetailLayout.interleavedInlineImageShadowRadius,
                y: MHBTheme.Spacing.s1
            )
            .overlay {
                inlineImageShape
                    .strokeBorder(MHBTheme.ColorToken.cardBorder.color, lineWidth: 1)
            }

            if let caption,
               !caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(caption)
                    .font(MHBTheme.Typography.footnote)
                    .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, MHBTheme.Spacing.s3)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var imageAspectRatio: CGFloat {
        guard let pixelSize = media.pixelSize,
              pixelSize.width > 0,
              pixelSize.height > 0
        else {
            return 4 / 3
        }

        return pixelSize.width / pixelSize.height
    }

    private var inlineImageShape: RoundedRectangle {
        RoundedRectangle(
            cornerRadius: PetWorldFeedDetailLayout.interleavedInlineImageCornerRadius,
            style: .continuous
        )
    }
}
