import SwiftUI
import MaohuobanDesignSystem

// HomeQuickFactOptionalPhotoSection 快捷记录可选照片区
// 核心职责：
// - 为喂食等记录提供可选照片入口
// - 在快速 UI 阶段使用本地 mock 图片表达添加状态
struct HomeQuickFactOptionalPhotoSection: View {
    let title: LocalizedStringResource
    @Binding var photoAssetNames: [String]

    private let mockAssetName = "HomePetFoodBowl"

    var body: some View {
        HomeQuickFactSheetSection(title: title) {
            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
                if photoAssetNames.isEmpty == false {
                    HStack(spacing: MHBTheme.Spacing.s2) {
                        ForEach(photoAssetNames, id: \.self) { assetName in
                            Image(assetName)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 78, height: 78)
                                .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
                        }
                    }
                }

                Button(action: toggleMockPhoto) {
                    HStack(spacing: MHBTheme.Spacing.s3) {
                        Image(systemName: photoAssetNames.isEmpty ? "camera.fill" : "xmark.circle.fill")
                            .font(.system(size: MHBTheme.IconSize.medium, weight: .semibold))

                        Text(photoAssetNames.isEmpty ? "添加照片" : "移除照片")
                            .font(MHBTheme.Typography.callout.weight(.semibold))

                        Spacer()

                        Image(systemName: photoAssetNames.isEmpty ? "plus" : "minus")
                            .font(.system(size: MHBTheme.IconSize.small, weight: .semibold))
                    }
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    .padding(MHBTheme.Spacing.s4)
                    .background(MHBTheme.ColorToken.cardSolid.color)
                    .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.extraLarge, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: MHBTheme.Radius.extraLarge, style: .continuous)
                            .stroke(MHBTheme.ColorToken.separator.color, style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func toggleMockPhoto() {
        if photoAssetNames.isEmpty {
            photoAssetNames = [mockAssetName]
        } else {
            photoAssetNames = []
        }
    }
}
