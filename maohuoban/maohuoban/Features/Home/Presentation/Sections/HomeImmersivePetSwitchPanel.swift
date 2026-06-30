import SwiftUI
import MaohuobanDesignSystem

// HomeImmersivePetSwitchPanel 首页沉浸式宠物切换面板
// 核心职责：
// - 展示最多三只可切换宠物
// - 在宠物数量超过三只时提供查看更多入口
struct HomeImmersivePetSwitchPanel: View {
    let pets: [HomeDashboardSnapshot.PetSwitchItem]
    let onSelectPet: (String) -> Void
    let onShowMore: () -> Void

    private var visiblePets: [HomeDashboardSnapshot.PetSwitchItem] {
        Array(pets.prefix(3))
    }

    private var showsMoreButton: Bool {
        pets.count > 3
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
            ForEach(visiblePets) { pet in
                Button {
                    guard !pet.isSelected else { return }
                    onSelectPet(pet.id)
                } label: {
                    HomeImmersivePetSwitchRow(pet: pet)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("home.petHeaderSwitchPanel.pet.\(pet.id)")
            }

            if showsMoreButton {
                Divider()
                    .overlay(.white.opacity(0.22))
                    .padding(.vertical, MHBTheme.Spacing.s1)

                Button(action: onShowMore) {
                    HStack(spacing: MHBTheme.Spacing.s3) {
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.system(size: MHBTheme.IconSize.medium, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.92))
                            .frame(width: 34, height: 34)

                        Text("查看更多")
                            .font(MHBTheme.Typography.footnote)
                            .foregroundStyle(.white.opacity(0.96))
                    }
                    .padding(.horizontal, MHBTheme.Spacing.s2)
                    .padding(.vertical, MHBTheme.Spacing.s2)
                    .contentShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("home.petHeaderSwitchPanel.more")
            }
        }
        .padding(MHBTheme.Spacing.s2)
        .frame(maxWidth: 190)
        .background {
            Color.black.opacity(0.16)
                .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
        }
        .glassEffect(.regular, in: .rect(cornerRadius: MHBTheme.Radius.large))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.petHeaderSwitchPanel")
    }
}

// HomeImmersivePetSwitchRow 首页沉浸式宠物切换行
// 核心职责：
// - 展示宠物头像、名称和当前选中态
// - 将行点击交给上层切换逻辑处理
private struct HomeImmersivePetSwitchRow: View {
    let pet: HomeDashboardSnapshot.PetSwitchItem

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s3) {
            HomeImmersivePetAvatar(
                avatarURL: pet.avatarURL,
                species: pet.species,
                isSelected: pet.isSelected,
                size: 34
            )

            Text(pet.name)
                .font(MHBTheme.Typography.footnote)
                .foregroundStyle(.white.opacity(pet.isSelected ? 1 : 0.88))
                .lineLimit(1)
                .truncationMode(.tail)

            if pet.isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: MHBTheme.IconSize.small, weight: .bold))
                    .foregroundStyle(.white.opacity(0.92))
            }
        }
        .padding(.horizontal, MHBTheme.Spacing.s2)
        .padding(.vertical, MHBTheme.Spacing.s2)
        .contentShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
        .opacity(pet.isSelected ? 1 : 0.92)
    }
}

// HomeImmersivePetAvatar 首页沉浸式宠物头像
// 核心职责：
// - 优先展示宠物远端头像
// - 在头像缺失时按物种展示稳定兜底图标
struct HomeImmersivePetAvatar: View {
    let avatarURL: String?
    let species: HomeDashboardSnapshot.Species
    let isSelected: Bool
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(.white.opacity(0.18))

            if let url = resolvedURL {
                MHBRemoteImage(url: url, contentMode: .fill) {
                    fallbackIcon
                }
            } else {
                fallbackIcon
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay {
            Circle()
                .stroke(
                    isSelected ? MHBTheme.ColorToken.primary.color : .white.opacity(0.24),
                    lineWidth: isSelected ? 2 : 1
                )
        }
        .overlay(alignment: .bottomTrailing) {
            if isSelected {
                Circle()
                    .fill(MHBTheme.ColorToken.primary.color)
                    .frame(width: max(size * 0.22, 8), height: max(size * 0.22, 8))
                    .overlay {
                        Circle()
                            .stroke(.white.opacity(0.92), lineWidth: 1)
                    }
            }
        }
        .contentShape(Circle())
    }

    private var fallbackIcon: some View {
        Image(systemName: iconName)
            .font(.system(size: max(size * 0.42, 14), weight: .semibold))
            .foregroundStyle(.white.opacity(0.92))
            .frame(width: size, height: size)
    }

    private var iconName: String {
        switch species {
        case .dog: "pawprint.fill"
        case .cat: "cat.fill"
        case .other: "heart.fill"
        }
    }

    private var resolvedURL: URL? {
        guard let avatarURL, avatarURL.isEmpty == false else {
            return nil
        }

        return MHBBackendEndpoint.resolve(avatarURL)
    }
}
