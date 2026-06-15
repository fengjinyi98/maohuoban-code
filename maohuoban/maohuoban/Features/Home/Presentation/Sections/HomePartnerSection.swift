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

                NavigationLink(value: HomeRoute.timelineEvent(eventID: "mock-partner")) {
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

            // 伙伴推荐平铺行布局（移除卡片包裹）
            HStack(alignment: .top, spacing: MHBTheme.Spacing.s4) {
                // 1. 左侧方形头像，带右上角粉色爱心角标（镂空融合效果）
                ZStack(alignment: .topTrailing) {
                    Image("HomePartnerAvatar")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 72, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        }
                        .mask(
                            RoundedRectangleWithCutout(cornerRadius: 16, cutoutRadius: 13)
                                .fill(style: FillStyle(eoFill: true))
                        )

                    // 爱心徽标挂件
                    Circle()
                        .fill(Color(hex: "F43F5E")) // 蔷薇红
                        .frame(width: 18, height: 18)
                        .overlay {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .offset(x: 9, y: -9)
                }

                // 2. 右侧字段布局 (名字/性别 -> 标签 -> 关系原因)
                VStack(alignment: .leading, spacing: 6) {
                    // 第一行：姓名 + 性别符号 (使用 SF Symbolsvenus/mars)
                    HStack(alignment: .bottom, spacing: 4) {
                        Text(partner.petName)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)

                        if let sex = partner.sex {
                            Image(systemName: sex == .female ? "venus" : "mars")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(sex == .female ? Color(hex: "F43F5E") : Color(hex: "3B82F6"))
                                .padding(.bottom, 2)
                        }
                    }

                    // 第二行：标签列表 (同窝标签 + 距离标签)
                    HStack(spacing: 6) {
                        // 关系标签
                        Text(relationTagText)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color(hex: "10B981"))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background {
                                Capsule()
                                    .fill(Color(hex: "10B981").opacity(0.12))
                            }

                        // 距离标签
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

                    // 第三行：推荐原因描述
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

// RoundedRectangleWithCutout 带右上角圆形切口的圆角矩形
// 核心职责：
// - 利用 Even-Odd Fill Rule 填充生成带缺口的圆角遮罩
// - 确保头像与角标挂件之间产生完美镂空融合效果
private struct RoundedRectangleWithCutout: Shape {
    var cornerRadius: CGFloat
    var cutoutRadius: CGFloat

    nonisolated func path(in rect: CGRect) -> Path {
        var path = Path()

        // 外部圆角矩形路径
        let outerRect = Path(roundedRect: rect, cornerRadius: cornerRadius)

        // 右上角挖空圆形路径
        var cutoutCircle = Path()
        cutoutCircle.addArc(
            center: CGPoint(x: rect.maxX, y: rect.minY),
            radius: cutoutRadius,
            startAngle: .degrees(0),
            endAngle: .degrees(360),
            clockwise: false
        )

        path.addPath(outerRect)
        path.addPath(cutoutCircle)
        return path
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


