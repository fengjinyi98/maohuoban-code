import SwiftUI
import MaohuobanDesignSystem

// MHBAvatar 通用头像组件
// 核心职责：
// - 统一渲染用户、宠物和人宠融合头像
// - 收敛头像形状、尺寸、描边和兜底图标
struct MHBAvatar: View {
    let subject: MHBAvatarSubject
    let size: MHBAvatarSize
    let shape: MHBAvatarShape

    init(
        subject: MHBAvatarSubject,
        size: MHBAvatarSize = .medium,
        shape: MHBAvatarShape = .circle
    ) {
        self.subject = subject
        self.size = size
        self.shape = shape
    }

    var body: some View {
        switch subject {
        case .user(let user):
            MHBSingleAvatar(
                source: user.source,
                fallbackSystemImage: "person.fill",
                palette: MHBAvatarBorderPalette.user(
                    sex: user.sex,
                    sexVisibility: user.sexVisibility
                ),
                size: size.value,
                shape: shape
            )
        case .pet(let pet):
            MHBSingleAvatar(
                source: pet.source,
                fallbackSystemImage: pet.species.fallbackSystemImage,
                palette: MHBAvatarBorderPalette.pet(sex: pet.sex),
                size: size.value,
                shape: shape
            )
        case let .petWithUser(pet, user):
            MHBCompositeAvatar(
                pet: pet,
                user: user,
                size: size
            )
        }
    }
}

// MHBCompositeAvatar 人宠融合头像
// 核心职责：
// - 以宠物头像作为主视觉
// - 在右下角叠加主人头像表达共同身份
struct MHBCompositeAvatar: View {
    let pet: MHBAvatarPet
    let user: MHBAvatarUser
    let size: MHBAvatarSize

    var body: some View {
        let dimension = size.value
        let ownerSize = MHBAvatarCompositeLayout.ownerAvatarSize(for: dimension)

        ZStack(alignment: .bottomTrailing) {
            MHBSingleAvatar(
                source: pet.source,
                fallbackSystemImage: pet.species.fallbackSystemImage,
                palette: MHBAvatarBorderPalette.pet(sex: pet.sex),
                size: dimension,
                shape: .circle
            )

            MHBSingleAvatar(
                source: user.source,
                fallbackSystemImage: "person.fill",
                palette: MHBAvatarBorderPalette.user(
                    sex: user.sex,
                    sexVisibility: user.sexVisibility
                ),
                size: ownerSize,
                shape: .circle,
                borderWidth: 2
            )
            .background(
                Circle()
                    .fill(MHBTheme.ColorToken.cardSolid.color)
                    .frame(width: ownerSize + 6, height: ownerSize + 6)
            )
            .offset(x: dimension * 0.08, y: dimension * 0.08)
        }
        .frame(width: dimension + dimension * 0.12, height: dimension + dimension * 0.12)
    }
}

// MHBSingleAvatar 单主体头像
// 核心职责：
// - 渲染单张头像图片和兜底图标
// - 按传入形状和色板绘制必选描边
private struct MHBSingleAvatar: View {
    let source: MHBAvatarSource
    let fallbackSystemImage: String
    let palette: MHBAvatarBorderPalette
    let size: CGFloat
    let shape: MHBAvatarShape
    var borderWidth: CGFloat = 3

    var body: some View {
        ZStack {
            palette.gradient

            avatarImage
                .frame(width: innerSize, height: innerSize)
                .clipShape(avatarShape(inset: borderWidth))
                .background(MHBTheme.ColorToken.cardSolid.color)
                .clipShape(avatarShape(inset: borderWidth))
        }
        .frame(width: size, height: size)
        .clipShape(avatarShape(inset: 0))
        .overlay {
            avatarShape(inset: borderWidth / 2)
                .stroke(palette.gradient, lineWidth: borderWidth)
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var avatarImage: some View {
        switch source {
        case .asset(let assetName):
            Image(assetName)
                .resizable()
                .scaledToFill()
        case .remote(let url):
            MHBRemoteImage(url: url, contentMode: .fill) {
                fallbackIcon
            }
        case .systemSymbol(let systemImage):
            fallbackIcon(systemImage: systemImage)
        case .empty:
            fallbackIcon
        }
    }

    private var fallbackIcon: some View {
        fallbackIcon(systemImage: fallbackSystemImage)
    }

    private func fallbackIcon(systemImage: String) -> some View {
        ZStack {
            MHBTheme.ColorToken.cardSolid.color
            Image(systemName: systemImage)
                .font(.system(size: max(size * 0.36, 12), weight: .semibold))
                .foregroundStyle(palette.foregroundColor)
        }
    }

    private var innerSize: CGFloat {
        max(size - borderWidth * 2, 1)
    }

    private func avatarShape(inset: CGFloat) -> some InsettableShape {
        RoundedRectangle(
            cornerRadius: max(shape.cornerRadius(for: size) - inset, 0),
            style: .continuous
        )
    }
}
