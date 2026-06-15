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
            // 头部：今日伙伴 与 换一换
            HStack {
                Text("今日伙伴")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)

                Spacer()

                Button(action: {
                    // Mock 换一换点击动作
                    print("Clicked refresh partner")
                }) {
                    HStack(spacing: 4) {
                        Text("换一换")
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, MHBTheme.Spacing.s1)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("home.partnerSection.header")

            // 伙伴推荐卡片
            HomeCardContainer(accessibilityIdentifier: "home.partnerSection.card") {
                HStack(alignment: .center, spacing: MHBTheme.Spacing.s4) {
                    // 1. 左侧圆形头像，带右上角粉色爱心角标
                    ZStack(alignment: .topTrailing) {
                        Image("HomePartnerAvatar")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 64, height: 64)
                            .clipShape(Circle())
                            .overlay {
                                Circle()
                                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                            }

                        // 爱心挂件
                        Circle()
                            .fill(Color(hex: "F43F5E")) // 蔷薇红/粉红
                            .frame(width: 20, height: 20)
                            .overlay {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                            .overlay {
                                Circle()
                                    .stroke(MHBTheme.ColorToken.card.color, lineWidth: 1.5)
                            }
                            .offset(x: 2, y: -2)
                    }

                    // 2. 中间核心字段区域
                    VStack(alignment: .leading, spacing: 5) {
                        // 第一行：姓名 + 性别符号
                        HStack(spacing: 6) {
                            Text(partner.petName)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)

                            if let sex = partner.sex {
                                Text(sex == .female ? "♀" : "♂")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(sex == .female ? Color(hex: "F43F5E") : Color(hex: "3B82F6"))
                            }
                        }

                        // 第二行：标签列表 (同窝妹妹/兄弟 + 距离)
                        HStack(spacing: 6) {
                            // 关系标签
                            Text(relationTagText)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color(hex: "10B981")) // 翡翠绿
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background {
                                    Capsule()
                                        .fill(Color(hex: "10B981").opacity(0.12))
                                }

                            // 距离标签 (例如 同城 · 2km)
                            if let distanceText = partner.distanceText {
                                Text("同城 · \(distanceText)")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.6))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background {
                                        Capsule()
                                            .fill(Color.white.opacity(0.08))
                                    }
                            }
                        }

                        // 第三行：描述文案
                        Text(partner.subtitle)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    // 3. 右侧操作按钮 "查看主页"
                    NavigationLink(value: HomeRoute.timelineEvent(eventID: "mock-partner")) {
                        Text("查看主页")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color(hex: "60A5FA")) // 浅蓝色
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background {
                                Capsule()
                                    .stroke(Color(hex: "60A5FA"), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
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

// 辅助 Color 的 Hex 初始化扩展
private extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}


