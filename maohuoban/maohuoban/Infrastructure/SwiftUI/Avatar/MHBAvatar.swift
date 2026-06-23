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
            .overlay(alignment: .bottomTrailing) {
                MHBAvatarGenderBadge(
                    sex: pet.sex,
                    avatarSize: size.value,
                    shape: shape
                )
            }
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
// - 以宠物头像作为主视觉并进行适当的尺寸放大
// - 在右下角叠加主人头像，并支持主人头像尺寸调大、位置往左上角微调
struct MHBCompositeAvatar: View {
    let pet: MHBAvatarPet
    let user: MHBAvatarUser
    let size: MHBAvatarSize

    var body: some View {
        let baseDimension = size.value
        // 适当放大 15% 以解决融合头像整体偏小的问题
        let dimension = baseDimension * 1.15
        // 宠物主人头像调整大一点：使用主头像宽度的 52% 比例
        let ownerSize = dimension * 0.52

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
                palette: nil,
                size: ownerSize,
                shape: .circle,
                borderWidth: 3
            )
            // 参照设计稿（bottom: -2px; right: -6px; 向右下外偏）并向左上角收缩微调以防遮挡
            .offset(x: dimension * 0.06, y: dimension * 0.02)
        }
        .frame(width: dimension + dimension * 0.12, height: dimension + dimension * 0.12)
    }
}

// MHBSingleAvatar 单主体头像
// 核心职责：
// - 渲染单张头像图片和兜底图标
// - 按传入形状和色板使用同心填充（concentric fill）渲染双层或单层描边，确保尺寸与裁剪框一致，彻底根除双边框锯齿
private struct MHBSingleAvatar: View {
    let source: MHBAvatarSource
    let fallbackSystemImage: String
    let palette: MHBAvatarBorderPalette?
    let size: CGFloat
    let shape: MHBAvatarShape
    var borderWidth: CGFloat? = nil

    private var baseShape: RoundedRectangle {
        RoundedRectangle(
            cornerRadius: shape.cornerRadius(for: size),
            style: .continuous
        )
    }

    private var outerBorderWidth: CGFloat {
        size >= 56 ? 2.0 : 1.5
    }

    private var innerBorderWidth: CGFloat {
        size >= 56 ? 1.5 : 1.0
    }

    var body: some View {
        ZStack {
            if let palette {
                // 双层同心描边模式（外层渐变 + 内层白色）
                let outerWidth = outerBorderWidth
                let innerWidth = innerBorderWidth

                baseShape.fill(palette.gradient)
                    .overlay {
                        baseShape.inset(by: outerWidth)
                            .fill(MHBTheme.ColorToken.cardSolid.color)
                    }
                    .overlay {
                        avatarImage
                            .frame(width: size, height: size)
                            .clipShape(baseShape.inset(by: outerWidth + innerWidth))
                    }
            } else {
                // 单层纯白描边模式（保证单层描边绝对纯净，主要用于主人头像 knockout）
                let strokeWidth = borderWidth ?? 3.0

                baseShape.fill(MHBTheme.ColorToken.cardSolid.color)
                    .overlay {
                        avatarImage
                            .frame(width: size, height: size)
                            .clipShape(baseShape.inset(by: strokeWidth))
                    }
            }
        }
        .frame(width: size, height: size)
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
                .foregroundStyle(palette?.foregroundColor ?? MHBTheme.ColorToken.labelTertiary.color)
        }
    }
}

// MHBAvatarGenderBadge 宠物头像性别角标
// 核心职责：
// - 根据宠物性别在头像右下角渲染对应的性别符号与背景色
// - 根据头像尺寸和形状自动计算大小与溢出偏移量
struct MHBAvatarGenderBadge: View {
    let sex: MHBAvatarSex
    let avatarSize: CGFloat
    let shape: MHBAvatarShape

    var body: some View {
        if sex == .male || sex == .female {
            badgeView
        }
    }

    private var badgeView: some View {
        let size = badgeSize
        let symbol = sex == .male ? "♂" : "♀"
        let bgColor = sex == .male
            ? Color(red: 59 / 255, green: 130 / 255, blue: 246 / 255)
            : Color(red: 236 / 255, green: 72 / 255, blue: 153 / 255)

        return Text(verbatim: symbol)
            .font(.system(size: size * 0.65, weight: .bold))
            .foregroundColor(.white)
            .frame(width: size, height: size)
            .background(bgColor)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(MHBTheme.ColorToken.cardSolid.color, lineWidth: 2)
            )
            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
            .offset(x: offset, y: offset)
    }

    private var badgeSize: CGFloat {
        if avatarSize >= 64 {
            return 22
        } else if avatarSize >= 56 {
            return 18
        } else {
            return 14
        }
    }

    private var offset: CGFloat {
        // 圆形头像不需要额外位移；方形头像性别角标向左上角内移，防止遮挡或被切除
        switch shape {
        case .circle:
            return 0
        case .squircle:
            if avatarSize >= 64 {
                return -2
            } else if avatarSize >= 56 {
                return -2
            } else {
                return -1.5
            }
        }
    }
}
