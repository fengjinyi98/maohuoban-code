import SwiftUI
import MaohuobanDesignSystem

// MerchantLitterDetailScreen 商家窝次详情页
// 核心职责：
// - 展示窝次基础信息、父母、同窝幼宠、关系边和近期事件
// - 通过 MerchantLitterDetailStore 加载认证商家窝次追溯详情
struct MerchantLitterDetailScreen: View {
    let merchantID: String
    let litterID: String
    let currentUserID: String?

    @State private var store = MerchantLitterDetailStore()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s4) {
                switch store.phase {
                case .idle, .loading:
                    MerchantLitterDetailLoadingSection()
                case .loaded(let detail):
                    MerchantLitterDetailLoadedView(detail: detail)
                case .failed(let message):
                    MerchantLitterDetailFailedSection(message: message)
                }
            }
            .padding(MHBTheme.Spacing.s4)
        }
        .frame(maxWidth: .infinity)
        .background(MHBTheme.ColorToken.background.color)
        .navigationTitle("窝次详情")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: taskID) {
            await store.load(
                merchantID: merchantID,
                litterID: litterID,
                currentUserID: currentUserID
            )
        }
        .accessibilityIdentifier("merchant.litterDetail.screen")
    }

    private var taskID: String {
        "\(merchantID)-\(litterID)-\(currentUserID ?? "anonymous")"
    }
}
