import CoreLocation
import SwiftUI
import UIKit
import MaohuobanDesignSystem

// PetWalkTrackingScreen 宠物遛弯记录页
// 核心职责：
// - 展示真实地图、用户位置和遛弯轨迹
// - 使用系统 sheet 承载遛弯数据和记录操作
struct PetWalkTrackingScreen: View {
    let context: PetRecordEntryContext
    let onFinished: () -> Void

    @State private var store = PetWalkTrackingStore()
    @State private var isTrackingSheetPresented = true
    @State private var recenterRequestID = 0

    var body: some View {
        ZStack {
            MHBRouteMapView(
                coordinates: store.points.map(\.coordinate),
                showsCurrentLocation: context.petID != nil,
                followsUser: store.phase == .tracking,
                petAvatarURL: resolvedPetAvatarURL,
                petMarkerColor: context.petSex.markerUIColor,
                recenterRequestID: recenterRequestID,
                onUserLocationUpdated: updateReferenceLocation
            )
            .ignoresSafeArea()

            if context.petID == nil {
                PetWalkUnavailablePanel()
            } else {
                PetWalkMapControls(
                    isSheetPresented: isTrackingSheetPresented,
                    onRecenter: recenterMap
                )

                if isTrackingSheetPresented == false {
                    PetWalkCollapsedSheetEntry(
                        store: store,
                        petName: context.petName,
                        petAvatarURL: resolvedPetAvatarURL,
                        petSex: context.petSex,
                        onOpenSheet: openTrackingSheet,
                        onStart: startTracking,
                        onPause: store.pause,
                        onResume: store.resume
                    )
                }
            }
        }
        .navigationTitle("遛弯")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                PetWalkNavigationStatus(
                    phase: store.phase,
                    gpsStatusText: store.gpsStatusText
                )
            }
        }
        .background {
            PetWalkScreenLifecycleObserver {
                dismissTrackingSheetBeforeNavigation()
            }
        }
        .sheet(isPresented: $isTrackingSheetPresented) {
            if context.petID != nil {
                PetWalkTrackingSheet(
                    store: store,
                    petName: context.petName,
                    petAvatarURL: resolvedPetAvatarURL,
                    petSex: context.petSex,
                    onStart: startTracking,
                    onPause: store.pause,
                    onResume: store.resume,
                    onFinish: finishTracking
                )
                .presentationDetents([.height(260), .medium])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(32)
                .presentationBackgroundInteraction(.enabled)
            }
        }
        .onAppear {
            isTrackingSheetPresented = context.petID != nil
        }
        .onDisappear {
            if store.phase == .tracking || store.phase == .paused {
                store.finish()
            }
        }
        .accessibilityIdentifier("pet.walkTracking.screen")
    }

    private var resolvedPetAvatarURL: URL? {
        guard let petAvatarURL = context.petAvatarURL else { return nil }
        return MHBBackendEndpoint.resolve(petAvatarURL)
    }

    private func recenterMap() {
        recenterRequestID += 1
    }

    private func updateReferenceLocation(_ location: CLLocation) {
        store.updateReferenceLocation(location)
    }

    private func openTrackingSheet() {
        isTrackingSheetPresented = true
    }

    private func startTracking() {
        guard context.petID != nil, store.canStartTracking else { return }
        store.start()
        recenterMap()
    }

    private func finishTracking() {
        dismissTrackingSheetBeforeNavigation()
        store.finish()
        onFinished()
    }

    private func dismissTrackingSheetBeforeNavigation() {
        guard isTrackingSheetPresented else { return }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isTrackingSheetPresented = false
        }
    }
}

// PetWalkScreenLifecycleObserver 遛弯页面生命周期观察器
// 核心职责：
// - 在系统导航 pop 动画开始前通知业务页收起 sheet
// - 保持系统返回按钮和侧滑返回路径不被业务页替换
private struct PetWalkScreenLifecycleObserver: UIViewControllerRepresentable {
    let onWillDisappear: () -> Void

    func makeUIViewController(context: Context) -> Controller {
        Controller()
    }

    func updateUIViewController(_ controller: Controller, context: Context) {
        controller.onWillDisappear = onWillDisappear
    }

    final class Controller: UIViewController {
        var onWillDisappear: (() -> Void)?

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            onWillDisappear?()
        }
    }
}

// PetWalkMapControls 地图浮动控件
// 核心职责：
// - 在地图上提供回到当前定位入口
// - 根据 sheet 展示状态调整按钮位置
private struct PetWalkMapControls: View {
    let isSheetPresented: Bool
    let onRecenter: () -> Void

    var body: some View {
        VStack {
            Spacer()

            HStack {
                Spacer()

                Button(action: onRecenter) {
                    Image(systemName: "scope")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                        .frame(width: 48, height: 48)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .circle)
                .shadow(color: Color.black.opacity(0.14), radius: 16, x: 0, y: 6)
                .padding(.trailing, MHBTheme.Spacing.s5)
                .padding(.bottom, isSheetPresented ? 286 : 132)
            }
        }
        .animation(.spring(response: 0.36, dampingFraction: 0.86), value: isSheetPresented)
        .accessibilityLabel("回到当前位置")
    }
}

// PetWalkNavigationStatus 遛弯导航栏状态
// 核心职责：
// - 在系统导航栏中展示当前记录状态
// - 展示 GPS 和权限状态提示
private struct PetWalkNavigationStatus: View {
    let phase: PetWalkSessionPhase
    let gpsStatusText: String

    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(MHBTheme.Typography.caption.weight(.bold))
                .foregroundStyle(titleColor)
            Label(gpsStatusText, systemImage: "location.fill")
                .font(MHBTheme.Typography.footnote)
                .foregroundStyle(statusColor)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
    }

    private var title: LocalizedStringResource {
        switch phase {
        case .ready:
            "准备记录路线"
        case .tracking:
            "正在记录路线"
        case .paused:
            "已暂停记录"
        case .finished:
            "本次遛弯已结束"
        }
    }

    private var titleColor: Color {
        switch phase {
        case .paused:
            MHBTheme.ColorToken.warning.color
        case .finished:
            MHBTheme.ColorToken.success.color
        case .ready, .tracking:
            MHBTheme.ColorToken.labelPrimary.color
        }
    }

    private var statusColor: Color {
        switch phase {
        case .tracking:
            MHBTheme.ColorToken.success.color
        case .paused:
            MHBTheme.ColorToken.warning.color
        case .ready, .finished:
            MHBTheme.ColorToken.labelSecondary.color
        }
    }
}

// PetWalkUnavailablePanel 遛弯不可用提示
// 核心职责：
// - 在未选择宠物时阻止开始遛弯
// - 保持页面仍可通过系统导航返回
private struct PetWalkUnavailablePanel: View {
    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s3) {
            Image(systemName: "pawprint.circle")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
            Text("未选择宠物")
                .font(MHBTheme.Typography.headline)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
            Text("请先创建或选择一只宠物")
                .font(MHBTheme.Typography.caption)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
        }
        .padding(MHBTheme.Spacing.s6)
        .glassEffect(.regular, in: .rect(cornerRadius: MHBTheme.Radius.extraLarge))
        .padding(.horizontal, MHBTheme.Spacing.s6)
    }
}

private extension PetRecordPetSex {
    var markerUIColor: UIColor {
        switch self {
        case .male:
            UIColor(red: 59 / 255, green: 130 / 255, blue: 246 / 255, alpha: 1)
        case .female:
            UIColor(red: 244 / 255, green: 63 / 255, blue: 94 / 255, alpha: 1)
        case .unknown:
            UIColor.black
        }
    }
}
