import SwiftUI
import MaohuobanDesignSystem

// ProfileUserRegionPickerScreen 用户所在地选择页
// 核心职责：
// - 使用前端本地地区字典完成省、市、区三级选择
// - 把最终选择结果回填到个人资料编辑页所在地草稿
struct ProfileUserRegionPickerScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selection: ProfileUserEditRegionSelection?
    @State private var level: ProfileUserRegionPickerLevel = .province
    @State private var currentProvinceCode: String?
    @State private var currentCityCode: String?
    @State private var hasInitializedState = false

    private let dictionary = ProfileUserEditRegionDictionary.frontEndFallback

    init(selection: Binding<ProfileUserEditRegionSelection?>) {
        self._selection = selection
    }

    var body: some View {
        MHBScreenScrollView {
            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s4) {
                ProfileUserRegionListSection(
                    items: currentItems,
                    onSelect: handleSelection
                )
            }
            .padding(.horizontal, MHBTheme.Spacing.s4)
            .padding(.top, MHBTheme.Spacing.s4)
            .padding(.bottom, MHBTheme.Spacing.s8)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(usesInternalBackNavigation)
        .toolbar {
            if usesInternalBackNavigation {
                ToolbarItem(placement: .topBarLeading) {
                    Button("上一级", action: handleLeadingAction)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                }
            }
        }
        .onAppear(perform: initializeStateIfNeeded)
        .accessibilityIdentifier("profile.userEdit.regionPicker.screen")
    }

    private var country: ProfileUserEditRegionDictionary.Country? {
        dictionary.countries.first
    }

    private var currentProvince: ProfileUserEditRegionDictionary.Province? {
        guard let country else { return nil }
        if let currentProvinceCode {
            return country.provinces.first { $0.code == currentProvinceCode }
        }
        if let provinceName = selection?.provinceName {
            return country.provinces.first { $0.name == provinceName }
        }
        return nil
    }

    private var currentCity: ProfileUserEditRegionDictionary.City? {
        guard let currentProvince else { return nil }
        if let currentCityCode {
            return currentProvince.cities.first { $0.code == currentCityCode }
        }
        if let cityName = selection?.cityName {
            return currentProvince.cities.first { $0.name == cityName }
        }
        return nil
    }

    private var currentItems: [ProfileUserRegionListItem] {
        switch level {
        case .province:
            return country?.provinces.map {
                ProfileUserRegionListItem(id: $0.code, title: $0.name, showsChevron: true)
            } ?? []
        case .city:
            return currentProvince?.cities.map {
                ProfileUserRegionListItem(id: $0.code, title: $0.name, showsChevron: !$0.districts.isEmpty)
            } ?? []
        case .district:
            return currentCity?.districts.map {
                ProfileUserRegionListItem(id: $0.code, title: $0.name, showsChevron: false)
            } ?? []
        }
    }

    private var navigationTitle: String {
        switch level {
        case .province:
            "选择所在地"
        case .city:
            currentProvince?.name ?? "选择城市"
        case .district:
            currentCity?.name ?? "选择区县"
        }
    }

    private var usesInternalBackNavigation: Bool {
        switch level {
        case .province:
            false
        case .city, .district:
            true
        }
    }

    private func initializeStateIfNeeded() {
        guard hasInitializedState == false else { return }
        defer { hasInitializedState = true }

        if let country,
           let selectedProvince = selection?.provinceName.flatMap({ provinceName in
               country.provinces.first { $0.name == provinceName }
           }) {
            currentProvinceCode = selectedProvince.code
        }

        if let selectedProvince = currentProvince,
           let selectedCity = selection?.cityName.flatMap({ cityName in
               selectedProvince.cities.first { $0.name == cityName }
           }) {
            currentCityCode = selectedCity.code
        }
    }

    private func handleLeadingAction() {
        switch level {
        case .province:
            dismiss()
        case .city:
            level = .province
        case .district:
            level = .city
        }
    }

    private func handleSelection(_ item: ProfileUserRegionListItem) {
        guard let country else { return }

        switch level {
        case .province:
            guard let province = country.provinces.first(where: { $0.code == item.id }) else { return }
            selection = (selection ?? .init()).selectingProvince(province, in: country)
            currentProvinceCode = province.code
            currentCityCode = nil
            level = .city
        case .city:
            guard let city = currentProvince?.cities.first(where: { $0.code == item.id }) else { return }
            selection = (selection ?? .init()).selectingCity(city)
            currentCityCode = city.code
            if city.districts.isEmpty {
                dismiss()
            } else {
                level = .district
            }
        case .district:
            guard let district = currentCity?.districts.first(where: { $0.code == item.id }) else { return }
            selection = (selection ?? .init()).selectingDistrict(district)
            dismiss()
        }
    }
}

// ProfileUserRegionPickerLevel 所在地选择层级
// 核心职责：
// - 表达当前正在选择省、市或区
// - 驱动导航标题和上一级行为
private enum ProfileUserRegionPickerLevel {
    case province
    case city
    case district
}

// ProfileUserRegionListItem 所在地选择列表项
// 核心职责：
// - 承载列表展示标题
// - 标记当前项是否还能继续进入下一级
private struct ProfileUserRegionListItem: Identifiable {
    let id: String
    let title: String
    let showsChevron: Bool
}

// ProfileUserRegionListSection 所在地选择列表分组
// 核心职责：
// - 展示当前层级的地区列表
// - 统一列表分割线和卡片表面
private struct ProfileUserRegionListSection: View {
    let items: [ProfileUserRegionListItem]
    let onSelect: (ProfileUserRegionListItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
            Text("全部")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
                .padding(.leading, MHBTheme.Spacing.s2)

            VStack(spacing: 0) {
                ForEach(items) { item in
                    ProfileUserRegionRow(
                        title: item.title,
                        showsChevron: item.showsChevron,
                        onTap: { onSelect(item) }
                    )

                    if item.id != items.last?.id {
                        Rectangle()
                            .fill(MHBTheme.ColorToken.separatorSoft.color)
                            .frame(height: 0.5)
                            .padding(.horizontal, MHBTheme.Spacing.s4)
                    }
                }
            }
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
        }
    }
}

// ProfileUserRegionRow 所在地选择行
// 核心职责：
// - 展示单个地区节点名称
// - 承载进入下一级或完成选择动作
private struct ProfileUserRegionRow: View {
    let title: String
    let showsChevron: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: MHBTheme.Spacing.s3) {
                Text(title)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

                Spacer()

                if showsChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
                }
            }
            .padding(.horizontal, MHBTheme.Spacing.s4)
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
