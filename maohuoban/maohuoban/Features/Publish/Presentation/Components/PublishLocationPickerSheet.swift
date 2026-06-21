import CoreLocation
import SwiftUI
import MaohuobanDesignSystem

// PublishLocationPickerSheet 发布地点选择弹层
// 核心职责：
// - 使用真实定位和 MapKit 搜索展示地点候选
// - 在确认后把结构化地点结果回写给发布页
struct PublishLocationPickerSheet: View {
    let selectedLocation: PublishLocation?
    let onSelectLocation: (PublishLocation?) -> Void
    let onDismiss: () -> Void

    @State private var currentSelected: PublishLocationOption?
    @State private var searchText = ""
    @State private var currentCity = "定位中"
    @State private var searchResults: [PublishLocationOption] = []
    @State private var locationService = MHBLocationService()
    @State private var searchScope: MHBLocationSearchScope = .nearby
    @State private var isSearching = false
    @FocusState private var isSearchFocused: Bool

    private let searchService = MHBLocationSearchService()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                PublishLocationSearchHeader(
                    searchText: $searchText,
                    isSearchFocused: $isSearchFocused,
                    scopeTitle: scopeTitle,
                    currentCity: currentCity,
                    onSelectNearbyScope: selectNearbyScope,
                    onSelectNationwideScope: selectNationwideScope
                )

                Divider()

                ZStack(alignment: .bottom) {
                    locationResultList

                    if currentSelected != nil {
                        Button(action: confirmSelection) {
                            Text("完成")
                                .font(MHBTheme.Typography.body.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(width: 160, height: 44)
                                .background(MHBTheme.ColorToken.primary.color, in: .capsule)
                                .shadow(
                                    color: MHBTheme.ColorToken.primary.color.opacity(0.3),
                                    radius: 8,
                                    y: 4
                                )
                        }
                        .padding(.bottom, MHBTheme.Spacing.s5)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.spring(), value: currentSelected?.id)
                    }
                }
            }
            .navigationTitle("地点")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消", action: onDismiss)
                        .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                }
            }
        }
        .task {
            syncSelectedLocation()
            locationService.refresh()
            await refreshSearchResults()
        }
        .onChange(of: searchText) { _, _ in
            Task {
                await refreshSearchResults()
            }
        }
        .onChange(of: locationService.snapshot) { _, newValue in
            currentCity = newValue?.displayName ?? "当前位置"
            Task {
                await refreshSearchResults()
            }
        }
    }

    @ViewBuilder
    private var locationResultList: some View {
        if isSearching, searchResults.isEmpty {
            ProgressView("正在搜索地点")
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if searchResults.isEmpty {
            PublishLocationEmptyState(
                title: emptyStateTitle,
                message: emptyStateMessage,
                actionTitle: locationService.isAuthorized ? "重新定位" : "请求定位权限",
                action: {
                    locationService.refresh()
                    Task {
                        await refreshSearchResults()
                    }
                }
            )
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(searchResults) { location in
                        PublishLocationPickerRow(
                            location: location,
                            isSelected: currentSelected?.id == location.id,
                            action: { selectLocation(location) }
                        )
                    }
                }
                .padding(.bottom, 100)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private func refreshSearchResults() async {
        isSearching = true
        defer { isSearching = false }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty {
            let nearbyResults = await searchService.nearby(around: currentReferenceLocation)
            if nearbyResults.isEmpty {
                let fallbackResults = await searchNearbyFallbacks()
                searchResults = fallbackResults.isEmpty
                    ? currentLocationFallbacks()
                    : fallbackResults.map(PublishLocationOption.init(searchResult:))
            } else {
                searchResults = nearbyResults.map(PublishLocationOption.init(searchResult:))
            }
            return
        }

        let results = await searchService.search(
            query: query,
            near: currentReferenceLocation,
            scope: searchScope
        )
        searchResults = results.map(PublishLocationOption.init(searchResult:))
    }

    private func currentLocationFallbacks() -> [PublishLocationOption] {
        guard let location = currentReferenceLocation else {
            return []
        }

        let snapshot = locationService.snapshot
        let title = snapshot?.displayName ?? "当前位置"
        let subtitle = currentLocationSubtitle
        let fallback = MHBLocationSearchResult(
            id: "\(location.coordinate.latitude),\(location.coordinate.longitude)",
            title: title,
            subtitle: subtitle,
            distanceText: "",
            distanceMeters: 0,
            country: snapshot?.country ?? "中国",
            province: snapshot?.province,
            city: snapshot?.city,
            district: snapshot?.district,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
        return [PublishLocationOption(searchResult: fallback)]
    }

    private func searchNearbyFallbacks() async -> [MHBLocationSearchResult] {
        for keyword in fallbackKeywords {
            let results = await searchService.search(
                query: keyword,
                near: currentReferenceLocation,
                scope: .nearby
            )
            if results.isEmpty == false {
                return results
            }
        }
        return []
    }

    private func selectLocation(_ location: PublishLocationOption) {
        withAnimation {
            currentSelected = location
        }
    }

    private func confirmSelection() {
        onSelectLocation(currentSelected?.location)
        onDismiss()
    }

    private func syncSelectedLocation() {
        currentSelected = selectedLocation.map { location in
            PublishLocationOption(
                searchResult: MHBLocationSearchResult(
                    id: location.stableSelectionID,
                    title: location.displayName,
                    subtitle: location.formattedAddress ?? "",
                    distanceText: "",
                    distanceMeters: nil,
                    country: location.country,
                    province: location.province,
                    city: location.city,
                    district: location.district,
                    latitude: location.latitude,
                    longitude: location.longitude
                )
            )
        }
        currentCity = locationService.displayName ?? selectedLocation?.city ?? "当前位置"
    }

    private var currentReferenceLocation: CLLocation? {
        guard let latitude = locationService.snapshot?.latitude,
              let longitude = locationService.snapshot?.longitude
        else {
            return nil
        }
        return CLLocation(latitude: latitude, longitude: longitude)
    }

    private var currentLocationSubtitle: String {
        [
            locationService.snapshot?.district,
            locationService.snapshot?.city,
            locationService.snapshot?.province,
        ]
        .compactMap { $0 }
        .joined(separator: " ")
        .nilIfEmpty ?? "使用设备 GPS 获取当前位置"
    }

    private var scopeTitle: String {
        searchScope == .nationwide ? "全部" : currentCity
    }

    private var fallbackKeywords: [String] {
        [
            locationService.snapshot?.district,
            locationService.snapshot?.city,
            locationService.snapshot?.province,
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { $0.isEmpty == false }
    }

    private var emptyStateTitle: String {
        if let errorMessage = locationService.errorMessage, errorMessage.isEmpty == false {
            return errorMessage
        }
        return searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "暂无附近地点"
            : "未找到相关地点"
    }

    private var emptyStateMessage: String {
        if locationService.isAuthorized == false {
            return "允许定位后，可以显示当前位置附近的地点。"
        }
        return "可以切换到全部范围，或换一个关键词搜索。"
    }

    private func selectNearbyScope() {
        searchScope = .nearby
        Task {
            await refreshSearchResults()
        }
    }

    private func selectNationwideScope() {
        searchScope = .nationwide
        Task {
            await refreshSearchResults()
        }
    }
}

// PublishLocationSearchHeader 地点搜索头部
// 核心职责：
// - 承载搜索范围菜单与搜索输入框
private struct PublishLocationSearchHeader: View {
    @Binding var searchText: String
    var isSearchFocused: FocusState<Bool>.Binding
    let scopeTitle: String
    let currentCity: String
    let onSelectNearbyScope: () -> Void
    let onSelectNationwideScope: () -> Void

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s2) {
            Menu {
                Button(currentCity, action: onSelectNearbyScope)
                Button("全部", action: onSelectNationwideScope)
            } label: {
                HStack(spacing: MHBTheme.Spacing.s1) {
                    Label(scopeTitle, systemImage: "location.fill")
                        .font(MHBTheme.Typography.callout.weight(.semibold))
                        .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

                    Image(systemName: "arrowtriangle.down.fill")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                }
            }

            Divider()
                .frame(height: 16)
                .padding(.horizontal, MHBTheme.Spacing.s1)

            TextField("搜索地点", text: $searchText)
                .focused(isSearchFocused)
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, MHBTheme.Spacing.s4)
        .background(MHBTheme.ColorToken.separatorSoft.color, in: .rect(cornerRadius: 18))
        .padding(.horizontal, MHBTheme.Spacing.s4)
        .padding(.bottom, MHBTheme.Spacing.s3)
    }
}

// PublishLocationEmptyState 地点选择空态
// 核心职责：
// - 展示定位或搜索失败时的可恢复状态
private struct PublishLocationEmptyState: View {
    let title: String
    let message: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s3) {
            Image(systemName: "mappin.slash")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)

            Text(title)
                .font(MHBTheme.Typography.body.weight(.semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

            Text(message)
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                .multilineTextAlignment(.center)
                .padding(.horizontal, MHBTheme.Spacing.s6)

            Button(actionTitle, action: action)
                .font(MHBTheme.Typography.callout.weight(.semibold))
                .foregroundStyle(MHBTheme.ColorToken.primary.color)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private extension PublishLocation {
    var stableSelectionID: String {
        [
            latitude.map { String($0) } ?? "",
            longitude.map { String($0) } ?? "",
            displayName,
            formattedAddress ?? "",
        ]
        .joined(separator: "|")
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
