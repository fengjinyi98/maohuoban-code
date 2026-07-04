import SwiftUI
import UIKit

// PantryItemCoverInput 物品照片输入区
// 核心职责：
// - 展示本地已选图片、远端图片或默认占位
// - 展示即时上传进度状态
struct PantryItemCoverInput: View {
    let imageURL: String?
    let selectedImage: UIImage?
    let uploadProgress: Double?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                coverContent
                if let uploadProgress {
                    Color.black.opacity(0.36)
                    ProgressView(value: uploadProgress)
                        .progressViewStyle(.circular)
                        .tint(.white)
                }
            }
            .frame(width: 140, height: 175)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: Color.black.opacity(0.04), radius: 24, x: 0, y: 8)
            .padding(.bottom, 32)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .disabled(uploadProgress != nil)
        .accessibilityLabel("添加物品照片")
    }

    @ViewBuilder
    private var coverContent: some View {
        if let selectedImage {
            Image(uiImage: selectedImage)
                .resizable()
                .scaledToFill()
        } else if let imageURL,
                  let url = PantryMediaURLResolver.resolve(imageURL) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    PantryItemCoverPlaceholder()
                }
            }
        } else {
            PantryItemCoverPlaceholder()
        }
    }
}
