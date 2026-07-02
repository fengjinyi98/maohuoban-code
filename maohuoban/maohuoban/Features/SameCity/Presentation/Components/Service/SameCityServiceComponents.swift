import SwiftUI
import MaohuobanDesignSystem

// SameCityServiceMatrix 同城业务金刚区
// 核心职责：
// - 展示同城四类高频业务入口
// - 参照设计稿维持四列轻量卡片布局
struct SameCityServiceMatrix: View {
    private let services = SameCityServiceItem.allCases

    var body: some View {
        LazyVGrid(
            columns: Array(
                repeating: GridItem(.flexible(), spacing: SameCityRootLayout.serviceItemSpacing),
                count: SameCityRootLayout.serviceColumnCount
            ),
            spacing: SameCityRootLayout.serviceItemSpacing
        ) {
            ForEach(services) { service in
                SameCityServiceButton(service: service)
            }
        }
        .padding(.top, MHBTheme.Spacing.s3)
        .padding(.bottom, MHBTheme.Spacing.s1)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("sameCity.service.matrix")
    }
}

// SameCityServiceButton 同城业务入口按钮
// 核心职责：
// - 呈现单个金刚区图标和标题
// - 保留后续接入业务路由的触控边界
struct SameCityServiceButton: View {
    let service: SameCityServiceItem

    var body: some View {
        Button {
            // 待接入同城业务入口。
        } label: {
            VStack(spacing: MHBTheme.Spacing.s2) {
                Image(systemName: service.systemImageName)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(service.tintColor)
                    .frame(
                        width: SameCityRootLayout.serviceIconSize,
                        height: SameCityRootLayout.serviceIconSize
                    )
                    .background(
                        MHBTheme.ColorToken.cardSolid.color,
                        in: .rect(cornerRadius: SameCityRootLayout.serviceIconCornerRadius)
                    )
                    .overlay {
                        RoundedRectangle(
                            cornerRadius: SameCityRootLayout.serviceIconCornerRadius,
                            style: .continuous
                        )
                        .strokeBorder(MHBTheme.ColorToken.separatorSoft.color, lineWidth: 1)
                    }

                Text(service.title)
                    .font(MHBTheme.Typography.caption.weight(.semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(service.title)
        .accessibilityIdentifier("sameCity.service.\(service.id)")
    }
}

// SameCityServiceItem 同城金刚区入口
// 核心职责：
// - 固化同城根页四项业务入口
// - 提供图标、文案和语义色
enum SameCityServiceItem: String, CaseIterable, Identifiable {
    case liveTrade
    case emergencyRescue
    case adoption
    case hospital

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .liveTrade: "活体买卖"
        case .emergencyRescue: "紧急救助"
        case .adoption: "爱心领养"
        case .hospital: "找医院"
        }
    }

    var systemImageName: String {
        switch self {
        case .liveTrade: "diamond.fill"
        case .emergencyRescue: "lifepreserver.fill"
        case .adoption: "house.fill"
        case .hospital: "cross.case.fill"
        }
    }

    var tintColor: Color {
        switch self {
        case .liveTrade:
            MHBTheme.ColorToken.warning.color
        case .emergencyRescue:
            MHBTheme.ColorToken.danger.color
        case .adoption:
            MHBTheme.ColorToken.success.color
        case .hospital:
            MHBTheme.ColorToken.primary.color
        }
    }
}
