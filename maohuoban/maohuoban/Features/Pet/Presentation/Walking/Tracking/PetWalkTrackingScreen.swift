import CoreLocation
import SwiftUI
import UIKit
import MaohuobanDesignSystem

// PetWalkTrackingScreen 宠物遛弯记录页
// 核心职责：
// - 展示真实地图、用户位置和遛弯轨迹
// - 使用系统 sheet 承载遛弯数据和记录操作
struct PetWalkTrackingScreen: View {
    @Environment(\.dismiss) private var dismiss

    let context: PetRecordEntryContext
    let onFinished: () -> Void

    @State private var store = PetWalkTrackingStore()
    @State private var selectedPet: PetRecordSwitchPet?
    @State private var isTrackingSheetPresented = true
    @State private var activeDetent: PresentationDetent = .height(260)
    @State private var recenterRequestID = 0
    @State private var windowSafeAreaInsets = UIEdgeInsets.zero
    @State private var completionSummary: PetWalkCompletionSummary?
    @State private var isWalkHistoryPresented = false

    init(
        context: PetRecordEntryContext,
        onFinished: @escaping () -> Void
    ) {
        self.context = context
        self.onFinished = onFinished
        self._selectedPet = State(initialValue: context.selectedSwitchPet)
    }

    var body: some View {
        GeometryReader { proxy in
            let effectiveBottomInset = max(proxy.safeAreaInsets.bottom, windowSafeAreaInsets.bottom)

            ZStack(alignment: .top) {
                MHBRouteMapView(
                    coordinates: store.points.map(\.coordinate),
                    showsCurrentLocation: currentPetID != nil,
                    followsUser: store.phase == .tracking,
                    petAvatarURL: resolvedPetAvatarURL,
                    petMarkerColor: currentPetSex.markerUIColor,
                    recenterRequestID: recenterRequestID,
                    onUserLocationUpdated: updateReferenceLocation
                )
                .frame(
                    width: proxy.size.width,
                    height: proxy.size.height + effectiveBottomInset
                )
                .ignoresSafeArea(.container, edges: [.top, .bottom])

                if currentPetID == nil {
                    PetWalkUnavailablePanel()
                } else {
                    PetWalkMapControls(
                        phase: store.phase,
                        gpsStatusText: store.gpsStatusText,
                        isSheetPresented: isTrackingSheetPresented,
                        activeDetent: activeDetent,
                        effectiveBottomInset: effectiveBottomInset,
                        screenHeight: proxy.size.height + effectiveBottomInset,
                        onRecenter: recenterMap
                    )

                    if isTrackingSheetPresented == false {
                        PetWalkCollapsedSheetEntry(
                            store: store,
                            petName: currentPetName,
                            petAvatarURL: resolvedPetAvatarURL,
                            petSex: currentPetSex,
                            bottomInset: effectiveBottomInset,
                            onOpenSheet: openTrackingSheet,
                            onStart: startTracking,
                            onPause: store.pause,
                            onResume: store.resume
                        )
                    }
                }

                MHBWindowSafeAreaReader { insets in
                    windowSafeAreaInsets = insets
                }
                .allowsHitTesting(false)

                PetWalkTopChrome(
                    petItem: currentPetSwitcherItem,
                    petItems: petSwitcherItems,
                    isPetSwitcherDisabled: store.phase != .ready || petSwitcherItems.isEmpty,
                    onBack: handleBack,
                    onSelectPet: selectPetForWalk,
                    onOpenHistory: openWalkHistory
                )
                .padding(.horizontal, MHBTheme.Spacing.s4)
                .mhbTopChromeAligned(geometrySafeAreaTop: proxy.safeAreaInsets.top)
                .zIndex(2)
            }
        }
        .ignoresSafeArea(.container, edges: [.top, .bottom])
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .background {
            PetWalkScreenLifecycleObserver(
                isSheetPresented: isTrackingSheetPresented,
                onWillDisappear: {
                    dismissTrackingSheetBeforeNavigation()
                }
            )
        }
        .sheet(isPresented: $isTrackingSheetPresented) {
            if currentPetID != nil {
                PetWalkTrackingSheet(
                    store: store,
                    petName: currentPetName,
                    petAvatarURL: resolvedPetAvatarURL,
                    petSex: currentPetSex,
                    onStart: startTracking,
                    onPause: store.pause,
                    onResume: store.resume,
                    onFinish: finishTracking
                )
                .presentationDetents([.height(260), .medium], selection: $activeDetent)
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(32)
                .presentationBackground(.clear)
                .presentationBackgroundInteraction(.enabled)
            }
        }
        .fullScreenCover(item: $completionSummary) { summary in
            PetWalkCompletionScreen(
                summary: summary,
                onSave: saveCompletedWalk
            )
        }
        .navigationDestination(isPresented: $isWalkHistoryPresented) {
            PetWalkHistoryScreen(context: context)
        }
        .onAppear {
            selectedPet = selectedPet ?? context.selectedSwitchPet
            isTrackingSheetPresented = currentPetID != nil
            if isTrackingSheetPresented {
                activeDetent = .height(260)
            }
        }
        .onDisappear {
            if store.phase == .tracking || store.phase == .paused {
                store.finish()
            }
        }
        .accessibilityIdentifier("pet.walkTracking.screen")
    }

    private var resolvedPetAvatarURL: URL? {
        guard let petAvatarURL = currentPetAvatarURL else { return nil }
        return MHBBackendEndpoint.resolve(petAvatarURL)
    }

    private var currentPetID: String? {
        selectedPet?.id ?? context.petID
    }

    private var currentPetName: String? {
        selectedPet?.name ?? context.petName
    }

    private var currentPetAvatarURL: String? {
        selectedPet?.avatarURL ?? context.petAvatarURL
    }

    private var currentPetSex: PetRecordPetSex {
        selectedPet?.sex ?? context.petSex
    }

    private var currentPetSwitcherItem: MHBPetSwitcherItem? {
        petSwitcherItems.first(where: \.isSelected)
    }

    private var petSwitcherItems: [MHBPetSwitcherItem] {
        let pets = context.availablePets.isEmpty
            ? selectedPet.map { [$0] } ?? []
            : context.availablePets

        guard let currentPetID else {
            return pets.map { MHBPetSwitcherItem(recordSwitchPet: $0, isSelected: false) }
        }

        return pets.map { pet in
            MHBPetSwitcherItem(recordSwitchPet: pet, isSelected: pet.id == currentPetID)
        }
    }

    private func recenterMap() {
        recenterRequestID += 1
    }

    private func updateReferenceLocation(_ location: CLLocation) {
        store.updateReferenceLocation(location)
    }

    private func openTrackingSheet() {
        activeDetent = .height(260)
        isTrackingSheetPresented = true
    }

    private func handleBack() {
        dismissTrackingSheetBeforeNavigation()
        // 延迟一个 runloop 确保 UIKit 层 sheet 已从层级移除再执行 NavigationStack pop
        DispatchQueue.main.async {
            dismiss()
        }
    }

    private func startTracking() {
        guard currentPetID != nil, store.canStartTracking else { return }
        store.start(petName: currentPetName, petAvatarURL: currentPetAvatarURL)
        recenterMap()
    }

    private func finishTracking() {
        let metrics = store.displayMetrics()
        let summary = PetWalkCompletionSummary(
            petName: currentPetName,
            petAvatarURL: resolvedPetAvatarURL,
            petSex: currentPetSex,
            metrics: metrics,
            routePoints: store.points.map(\.coordinate)
        )
        dismissTrackingSheetBeforeNavigation()
        store.finish()
        DispatchQueue.main.async {
            completionSummary = summary
        }
    }

    private func dismissTrackingSheetBeforeNavigation() {
        guard isTrackingSheetPresented else { return }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isTrackingSheetPresented = false
        }
    }

    private func selectPetForWalk(_ petID: String) {
        guard store.phase == .ready else { return }
        guard let pet = context.availablePets.first(where: { $0.id == petID }) else { return }
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

    private func saveCompletedWalk() {
        completionSummary = nil
        DispatchQueue.main.async {
            onFinished()
            dismiss()
        }
    }

    private func openWalkHistory() {
        dismissTrackingSheetBeforeNavigation()
        DispatchQueue.main.async {
            isWalkHistoryPresented = true
        }
    }
}



private extension PetRecordPetSex {
    var markerUIColor: UIColor {
        let rgb = walkMarkerRGB
        return UIColor(red: rgb.red, green: rgb.green, blue: rgb.blue, alpha: 1)
    }
}

private extension MHBPetSwitcherItem {
    init(recordSwitchPet pet: PetRecordSwitchPet, isSelected: Bool) {
        self.init(
            id: pet.id,
            name: pet.name ?? "未命名宠物",
            subtitle: pet.breed,
            avatarURLString: pet.avatarURL,
            species: MHBPetSwitcherSpecies(recordSpecies: pet.species),
            sex: MHBPetSwitcherSex(recordSex: pet.sex),
            isSelected: isSelected
        )
    }
}

private extension MHBPetSwitcherSpecies {
    init(recordSpecies: PetRecordPetSpecies) {
        switch recordSpecies {
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
    init(recordSex: PetRecordPetSex) {
        switch recordSex {
        case .female:
            self = .female
        case .male:
            self = .male
        case .unknown:
            self = .unknown
        }
    }
}
