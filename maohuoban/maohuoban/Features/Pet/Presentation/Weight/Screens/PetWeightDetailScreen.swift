import Foundation
import SwiftUI
import UIKit
import MaohuobanDesignSystem

// PetWeightDetailRoute 体重详情内部路由
// 核心职责：
// - 定义体重详情页内的二级推进目标
private enum PetWeightDetailRoute: Hashable, Identifiable {
    case history
    case recordDetail(String)

    var id: Self { self }
}

// PetWeightDetailScreen 宠物体重详情页面
// 核心职责：
// - 展示当前体重、趋势图和近期记录
// - 通过底部悬浮 CTA 进入新增体重记录流程
struct PetWeightDetailScreen: View {
    @Environment(\.dismiss) private var dismiss

    let context: PetWeightDetailContext

    @State private var selectedRange: PetWeightRange = .sixMonths
    @State private var selectedPet: PetRecordSwitchPet?
    @State private var isAddRecordSheetPresented = false
    @State private var pathRoute: PetWeightDetailRoute?
    @State private var windowSafeAreaInsets = UIEdgeInsets.zero
    @State private var store: PetWeightRecordStore

    init(context: PetWeightDetailContext) {
        self.context = context
        self._selectedPet = State(initialValue: context.recordContext.selectedSwitchPet)
        self._store = State(initialValue: PetWeightRecordStore(
            petID: context.petID,
            currentUserID: context.currentUserID ?? ""
        ))
    }

    var body: some View {
        GeometryReader { proxy in
            let topInset = effectiveTopInset(geometrySafeAreaTop: proxy.safeAreaInsets.top)
            let bottomInset = proxy.safeAreaInsets.bottom

            ZStack(alignment: .topLeading) {
                MHBTheme.ColorToken.background.color
                    .ignoresSafeArea()

                MHBScreenScrollView {
                    VStack(alignment: .leading, spacing: MHBTheme.Spacing.s5) {
                        if store.shouldShowEmptyState {
                            PetWeightEmptyState(
                                title: store.emptyStateTitle,
                                message: emptyStateMessage,
                                buttonTitle: store.emptyStateButtonTitle,
                                action: {
                                    isAddRecordSheetPresented = true
                                }
                            )
                            .frame(maxWidth: .infinity, minHeight: max(proxy.size.height - topContentPadding(topInset: topInset) - bottomInset, 320))
                        } else if store.shouldShowErrorState {
                            PetWeightLoadErrorState(
                                message: store.errorMessage ?? "体重记录加载失败",
                                action: {
                                    Task {
                                        await store.load()
                                    }
                                }
                            )
                            .frame(maxWidth: .infinity, minHeight: max(proxy.size.height - topContentPadding(topInset: topInset) - bottomInset, 320))
                        } else {
                            PetWeightHeroCard(
                                currentWeightText: store.currentWeightText,
                                changeText: store.weightChangeText
                            )

                            PetWeightChartCard(
                                selectedRange: $selectedRange,
                                records: store.records
                            )

                            PetWeightHistorySection(
                                presentation: store.recentHistory,
                                onOpenRecord: { record in
                                    pathRoute = .recordDetail(record.id)
                                },
                                onOpenHistory: {
                                    pathRoute = .history
                                }
                            )
                            .padding(.bottom, MHBTheme.Spacing.s8 + MHBTheme.Spacing.s8 + MHBTheme.Spacing.s6)
                        }
                    }
                    .padding(.horizontal, MHBTheme.Spacing.s5)
                    .padding(.top, topContentPadding(topInset: topInset))
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .zIndex(0)

                MHBWindowSafeAreaReader { insets in
                    windowSafeAreaInsets = insets
                }
                .allowsHitTesting(false)

                if store.shouldShowBottomCTA {
                    MHBBottomFloatingActionCTA(
                        title: "新增记录",
                        systemImage: "plus",
                        bottomInset: bottomInset,
                        action: {
                            isAddRecordSheetPresented = true
                        }
                    )
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottom)
                    .zIndex(2)
                }

                PetWeightDetailTopChrome(
                    selectedItem: currentPetSwitcherItem,
                    items: petSwitcherItems,
                    isDisabled: petSwitcherItems.count <= 1,
                    onBack: { dismiss() },
                    onSelect: selectPet
                )
                .padding(.horizontal, MHBTheme.Spacing.s4)
                .padding(.top, topInset)
                .frame(maxWidth: .infinity, alignment: .top)
                .zIndex(3)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
        .ignoresSafeArea(.container, edges: [.top, .bottom])
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .navigationDestination(item: $pathRoute) { route in
            switch route {
            case .history:
                PetWeightHistoryScreen(
                    context: context.recordContext,
                    fallbackPetName: currentPetName,
                    store: store
                )
            case .recordDetail(let recordID):
                PetWeightRecordDetailScreen(
                    recordID: recordID,
                    petName: currentPetName,
                    store: store
                )
            }
        }
        .task(id: context.petID) {
            await store.load()
        }
        .sheet(isPresented: $isAddRecordSheetPresented) {
            PetWeightRecordSheet(
                petName: currentPetName,
                initialWeightText: store.currentWeightText == "--" ? "" : store.currentWeightText,
                onSave: { draft in
                    await store.create(draft: draft)
                }
            )
        }
        .accessibilityIdentifier("pet.weightDetail")
    }

    private var topChromeHeight: CGFloat {
        48
    }

    private func effectiveTopInset(geometrySafeAreaTop: CGFloat) -> CGFloat {
        max(geometrySafeAreaTop, windowSafeAreaInsets.top)
    }

    private func topContentPadding(topInset: CGFloat) -> CGFloat {
        topInset + topChromeHeight + MHBTheme.Spacing.s5
    }

    private var currentPetID: String {
        selectedPet?.id ?? context.petID
    }

    private var currentPetName: String {
        selectedPet?.name ?? context.petName
    }

    private var emptyStateMessage: String {
        "记录第一次称重后，就能看到\(currentPetName)的体重变化。"
    }

    private var availablePets: [PetRecordSwitchPet] {
        if context.recordContext.availablePets.isEmpty == false {
            return context.recordContext.availablePets
        }

        return context.recordContext.selectedSwitchPet.map { [$0] } ?? []
    }

    private var currentPetSwitcherItem: MHBPetSwitcherItem? {
        petSwitcherItems.first(where: \.isSelected)
    }

    private var petSwitcherItems: [MHBPetSwitcherItem] {
        availablePets.map { pet in
            MHBPetSwitcherItem(weightRecordPet: pet, isSelected: pet.id == currentPetID)
        }
    }

    private func selectPet(_ petID: String) {
        guard let pet = availablePets.first(where: { $0.id == petID }) else { return }
        selectedPet = PetRecordSwitchPet(
            id: pet.id,
            name: pet.name,
            species: pet.species,
            breed: pet.breed,
            avatarURL: pet.avatarURL,
            sex: pet.sex,
            isSelected: true
        )
    }

}

// PetWeightLoadErrorState 体重记录加载错误态
// 核心职责：
// - 避免请求失败被误展示为空记录
// - 提供用户可恢复的重新加载入口
private struct PetWeightLoadErrorState: View {
    let message: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s4) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.warning.color)
                .frame(width: 72, height: 72)
                .background(MHBTheme.ColorToken.warning.color.opacity(0.10), in: Circle())

            VStack(spacing: MHBTheme.Spacing.s2) {
                Text("体重记录加载失败")
                    .font(MHBTheme.Typography.headline.weight(.semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

                Text(message)
                    .font(MHBTheme.Typography.callout)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: action) {
                Text("重新加载")
                    .font(MHBTheme.Typography.callout.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, MHBTheme.Spacing.s5)
                    .frame(height: 44)
                    .background(MHBTheme.ColorToken.primary.color, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, MHBTheme.Spacing.s6)
        .accessibilityIdentifier("pet.weight.errorState")
    }
}

// PetWeightRange 体重趋势周期
// 核心职责：
// - 定义体重趋势图的可选时间范围
// - 为周期切换控件提供稳定展示文案





// 核心职责：
// - 在系统导航栏视觉位置展示返回、标题和宠物切换
// - 使用自绘 chrome 承载带 Liquid Glass 的宠物切换基础设施
private struct PetWeightDetailTopChrome: View {
    let selectedItem: MHBPetSwitcherItem?
    let items: [MHBPetSwitcherItem]
    let isDisabled: Bool
    let onBack: () -> Void
    let onSelect: (String) -> Void

    var body: some View {
        GlassEffectContainer(spacing: MHBTheme.Spacing.s3) {
            ZStack {
                HStack(spacing: MHBTheme.Spacing.s3) {
                    PetWeightDetailBackButton(onBack: onBack)

                    Spacer(minLength: MHBTheme.Spacing.s3)
                }

                Text("体重")
                    .font(MHBTheme.Typography.headline.weight(.semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                    .frame(height: 48)
                    .accessibilityAddTraits(.isHeader)

                HStack {
                    Spacer(minLength: MHBTheme.Spacing.s3)

                    PetWeightDetailPetSwitcherMenu(
                        selectedItem: selectedItem,
                        items: items,
                        isDisabled: isDisabled,
                        onSelect: onSelect
                    )
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// PetWeightDetailBackButton 体重详情返回按钮
// 核心职责：
// - 承载顶部左侧返回动作
// - 保持自绘顶部栏 Liquid Glass 圆形反馈
private struct PetWeightDetailBackButton: View {
    let onBack: () -> Void

    var body: some View {
        Button(action: onBack) {
            Image(systemName: "chevron.left")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .frame(width: 48, height: 48)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel("返回")
        .accessibilityIdentifier("pet.weightDetail.backButton")
    }
}

// PetWeightDetailPetSwitcherMenu 体重详情宠物切换菜单
// 核心职责：
// - 在自绘顶部栏右侧展示当前宠物胶囊
// - 使用原生 Menu 承载多宠切换动作
private struct PetWeightDetailPetSwitcherMenu: View {
    let selectedItem: MHBPetSwitcherItem?
    let items: [MHBPetSwitcherItem]
    let isDisabled: Bool
    let onSelect: (String) -> Void

    var body: some View {
        Menu {
            ForEach(items) { item in
                Button {
                    onSelect(item.id)
                } label: {
                    Label(item.name, systemImage: item.isSelected ? "checkmark.circle.fill" : "circle")
                }
            }
        } label: {
            MHBPetSwitcherCapsule(
                item: selectedItem,
                isDisabled: false
            )
        }
        .disabled(items.isEmpty)
        .accessibilityIdentifier("pet.weightDetail.petSwitcherButton")
    }
}

private extension MHBPetSwitcherItem {
    init(weightRecordPet pet: PetRecordSwitchPet, isSelected: Bool) {
        self.init(
            id: pet.id,
            name: pet.name ?? "未命名宠物",
            subtitle: pet.breed,
            avatarURLString: pet.avatarURL,
            species: MHBPetSwitcherSpecies(weightRecordSpecies: pet.species),
            sex: MHBPetSwitcherSex(weightRecordSex: pet.sex),
            isSelected: isSelected
        )
    }
}

private extension MHBPetSwitcherSpecies {
    init(weightRecordSpecies species: PetRecordPetSpecies) {
        switch species {
        case .dog:
            self = .dog
        case .cat:
            self = .cat
        case .other:
            self = .other
        }
    }
}

private extension MHBPetSwitcherSex {
    init(weightRecordSex sex: PetRecordPetSex) {
        switch sex {
        case .female:
            self = .female
        case .male:
            self = .male
        case .unknown:
            self = .unknown
        }
    }
}
