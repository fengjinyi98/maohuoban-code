import SwiftUI
import MaohuobanDesignSystem

// PetProfileAddAvatarHeader 添加宠物头像入口
// 核心职责：
// - 展示添加页顶部头像占位
// - 为后续接入头像上传保留入口
struct PetProfileAddAvatarHeader: View {
    let species: PetSpecies

    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s2) {
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(MHBTheme.ColorToken.primaryBackground.color)
                    .frame(width: 88, height: 88)
                    .overlay {
                        Image(systemName: speciesSystemImage)
                            .font(.system(size: 36, weight: .semibold))
                            .foregroundStyle(MHBTheme.ColorToken.primary.color)
                    }

                Image(systemName: "camera.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(Color.black.opacity(0.78))
                    .clipShape(Circle())
                    .overlay {
                        Circle()
                            .strokeBorder(Color(uiColor: .systemGroupedBackground), lineWidth: 2)
                    }
            }

            Text("添加头像")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, MHBTheme.Spacing.s2)
    }

    private var speciesSystemImage: String {
        switch species {
        case .dog: "dog.fill"
        case .cat: "cat.fill"
        case .other: "pawprint.fill"
        }
    }
}
