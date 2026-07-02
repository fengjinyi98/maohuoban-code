import SwiftUI
import MaohuobanDesignSystem

// HomePartnerSection 今日伙伴模块
// 核心职责：
// - 展示一条高质量宠物关系提示
// - 呈现精美高颜值卡片布局，支持换一换刷新和主页跳转
struct HomePartnerSection: View {
    let partner: HomeDashboardSnapshot.PartnerRecommendation

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
            // 头部：今日伙伴 与 右上角 查看主页（带右向箭头样式）
            HStack(alignment: .center) {
                Text("今日伙伴")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)

                Spacer()

                NavigationLink(value: HomeRoute.petRecordDetail(PetRecordDetailRoute.mockRoute(for: "mock-partner"))) {
                    HStack(spacing: 4) {
                        Text("查看主页")
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("home.partnerSection.header")

            HStack(alignment: .top, spacing: MHBTheme.Spacing.s4) {
                MHBAvatar(
                    subject: HomePartnerAvatarPresentation.avatarSubject(for: partner),
                    size: .custom(72),
                    shape: .squircle
                )

                VStack(alignment: .leading, spacing: 6) {
                    Text(partner.petName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)

                    HStack(spacing: 6) {
                        MHBTagView(relationTagText, style: .success, size: .small)

                        if let distanceText = partner.distanceText {
                            MHBTagView("同城 · \(distanceText)", style: .whiteTranslucent, size: .small)
                        }
                    }

                    Text(partner.subtitle)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("home.partnerSection.contentRow")
        }
    }

    private var relationTagText: String {
        switch partner.relationshipKind {
        case .sameLitter:
            return partner.sex == .female ? "同窝妹妹" : (partner.sex == .male ? "同窝兄弟" : "同窝伙伴")
        case .sameCity:
            return "同城伙伴"
        case .sameCondition:
            return "健康同步"
        case .sameHospital:
            return "同院宠友"
        case .sameSource:
            return "同源伙伴"
        }
    }
}

// HomePartnerAvatarPresentation 今日伙伴头像展示映射器
// 核心职责：
// - 将今日伙伴推荐数据映射为宠物头像主体
// - 固化今日伙伴使用方形宠物头像的输入语义
enum HomePartnerAvatarPresentation {
    static func avatarSubject(for partner: HomeDashboardSnapshot.PartnerRecommendation) -> MHBAvatarSubject {
        .pet(
            MHBAvatarPet(
                id: partner.petID,
                name: partner.petName,
                source: .asset("HomePartnerAvatar"),
                species: .other,
                sex: partner.sex?.avatarSex ?? .unknown
            )
        )
    }
}

private extension HomeDashboardSnapshot.Sex {
    nonisolated var avatarSex: MHBAvatarSex {
        switch self {
        case .male:
            .male
        case .female:
            .female
        case .unknown:
            .unknown
        }
    }
}
