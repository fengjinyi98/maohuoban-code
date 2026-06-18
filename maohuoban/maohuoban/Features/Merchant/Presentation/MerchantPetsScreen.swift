import SwiftUI
import MaohuobanDesignSystem

// MerchantPetsScreen 商家宠物列表页
// 核心职责：
// - 展示指定商家和状态下的在管宠物
// - 通过 MerchantPetsStore 触发列表加载并渲染状态
struct MerchantPetsScreen: View {
    let merchantID: String
    let status: MerchantPetStatus
    let currentUserID: String?

    @State private var store = MerchantPetsStore()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s4) {
                switch store.phase {
                case .idle, .loading:
                    MerchantPetsLoadingSection(status: status)
                case .loaded(let list):
                    MerchantPetsLoadedSection(list: list)
                case .failed(let message):
                    MerchantPetsFailedSection(message: message)
                }
            }
            .padding(MHBTheme.Spacing.s4)
        }
        .frame(maxWidth: .infinity)
        .background(MHBTheme.ColorToken.background.color)
        .navigationTitle(Text(status.sectionTitle))
        .task(id: taskID) {
            await store.load(
                merchantID: merchantID,
                status: status,
                currentUserID: currentUserID
            )
        }
        .accessibilityIdentifier("merchant.pets.screen")
    }

    private var taskID: String {
        "\(merchantID)-\(status.rawValue)-\(currentUserID ?? "anonymous")"
    }
}
