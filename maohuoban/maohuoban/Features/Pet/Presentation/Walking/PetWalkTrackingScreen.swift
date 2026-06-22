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
    @State private var isTrackingSheetPresented = true
    @State private var activeDetent: PresentationDetent = .height(260)
    @State private var recenterRequestID = 0
    @State private var windowSafeAreaInsets = UIEdgeInsets.zero

    var body: some View {
        GeometryReader { proxy in
            let effectiveTopInset = max(proxy.safeAreaInsets.top, windowSafeAreaInsets.top)
            let effectiveBottomInset = max(proxy.safeAreaInsets.bottom, windowSafeAreaInsets.bottom)

            ZStack(alignment: .top) {
                MHBRouteMapView(
                    coordinates: store.points.map(\.coordinate),
                    showsCurrentLocation: context.petID != nil,
                    followsUser: store.phase == .tracking,
                    petAvatarURL: resolvedPetAvatarURL,
                    petMarkerColor: context.petSex.markerUIColor,
                    recenterRequestID: recenterRequestID,
                    onUserLocationUpdated: updateReferenceLocation
                )
                .frame(
                    width: proxy.size.width,
                    height: proxy.size.height + effectiveBottomInset
                )
                .ignoresSafeArea(.container, edges: [.top, .bottom])

                if context.petID == nil {
                    PetWalkUnavailablePanel()
                } else {
                    PetWalkMapControls(
                        isSheetPresented: isTrackingSheetPresented,
                        activeDetent: activeDetent,
                        effectiveBottomInset: effectiveBottomInset,
                        screenHeight: proxy.size.height + effectiveBottomInset,
                        onRecenter: recenterMap
                    )

                    if isTrackingSheetPresented == false {
                        PetWalkCollapsedSheetEntry(
                            store: store,
                            petName: context.petName,
                            petAvatarURL: resolvedPetAvatarURL,
                            petSex: context.petSex,
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
                    #if DEBUG
                    print("[DEBUG:WalkGlass] window safeArea top=\(insets.top) bottom=\(insets.bottom) left=\(insets.left) right=\(insets.right)")
                    #endif
                }
                .allowsHitTesting(false)

                #if DEBUG
                PetWalkRootLayoutDiagnostics(
                    proxy: proxy,
                    windowSafeAreaInsets: windowSafeAreaInsets,
                    effectiveTopInset: effectiveTopInset,
                    effectiveBottomInset: effectiveBottomInset
                )
                #endif

                PetWalkTopChrome(
                    phase: store.phase,
                    gpsStatusText: store.gpsStatusText,
                    onBack: handleBack
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
                .presentationDetents([.height(260), .medium], selection: $activeDetent)
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(32)
                .presentationBackground(.clear)
                .presentationBackgroundInteraction(.enabled)
            }
        }
        .onAppear {
            #if DEBUG
            print("[DEBUG:WalkGlass] screen appear sheet=\(isTrackingSheetPresented) petExists=\(context.petID != nil) phase=\(store.phase)")
            #endif
            isTrackingSheetPresented = context.petID != nil
            if isTrackingSheetPresented {
                activeDetent = .height(260)
            }
        }
        .onChange(of: isTrackingSheetPresented) { _, newValue in
            #if DEBUG
            print("[DEBUG:WalkGlass] sheet state changed presented=\(newValue) phase=\(store.phase)")
            #endif
        }
        .onDisappear {
            #if DEBUG
            print("[DEBUG:WalkGlass] screen disappear sheet=\(isTrackingSheetPresented) phase=\(store.phase)")
            #endif
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
// - sheet 展示期间禁用侧滑返回手势，强制走 handleBack 确保 sheet 先 dismiss 再 pop
private struct PetWalkScreenLifecycleObserver: UIViewControllerRepresentable {
    let isSheetPresented: Bool
    let onWillDisappear: () -> Void

    func makeUIViewController(context: Context) -> Controller {
        Controller()
    }

    func updateUIViewController(_ controller: Controller, context: Context) {
        controller.onWillDisappear = onWillDisappear
        controller.isSheetPresented = isSheetPresented
    }

    final class Controller: UIViewController {
        var onWillDisappear: (() -> Void)?
        var isSheetPresented: Bool = false {
            didSet {
                guard oldValue != isSheetPresented else { return }
                navigationController?.interactivePopGestureRecognizer?.isEnabled = !isSheetPresented
            }
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            // 确保手势状态与当前 sheet 状态一致
            navigationController?.interactivePopGestureRecognizer?.isEnabled = !isSheetPresented
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            // 即将离开页面时恢复手势
            navigationController?.interactivePopGestureRecognizer?.isEnabled = true
            onWillDisappear?()
        }
    }
}

#if DEBUG
// PetWalkRootLayoutDiagnostics 遛弯根布局临时诊断
// 核心职责：
// - 打印根视图尺寸和安全区
// - 协助定位地图是否延伸到导航栏区域
private struct PetWalkRootLayoutDiagnostics: View {
    let proxy: GeometryProxy
    let windowSafeAreaInsets: UIEdgeInsets
    let effectiveTopInset: CGFloat
    let effectiveBottomInset: CGFloat

    var body: some View {
        Color.clear
            .allowsHitTesting(false)
            .onAppear {
                print("[DEBUG:WalkGlass] root layout size=\(proxy.size.debugDescription) geometrySafeTop=\(proxy.safeAreaInsets.top) geometrySafeBottom=\(proxy.safeAreaInsets.bottom) windowSafeTop=\(windowSafeAreaInsets.top) windowSafeBottom=\(windowSafeAreaInsets.bottom) effectiveTop=\(effectiveTopInset) effectiveBottom=\(effectiveBottomInset)")
            }
            .onChange(of: proxy.safeAreaInsets.top) { _, newValue in
                print("[DEBUG:WalkGlass] root geometrySafeTop changed=\(newValue) effectiveTop=\(effectiveTopInset) size=\(proxy.size.debugDescription)")
            }
            .onChange(of: proxy.safeAreaInsets.bottom) { _, newValue in
                print("[DEBUG:WalkGlass] root geometrySafeBottom changed=\(newValue) effectiveBottom=\(effectiveBottomInset) size=\(proxy.size.debugDescription)")
            }
            .onChange(of: windowSafeAreaInsets.top) { _, newValue in
                print("[DEBUG:WalkGlass] root windowSafeTop changed=\(newValue) effectiveTop=\(effectiveTopInset) size=\(proxy.size.debugDescription)")
            }
            .onChange(of: windowSafeAreaInsets.bottom) { _, newValue in
                print("[DEBUG:WalkGlass] root windowSafeBottom changed=\(newValue) effectiveBottom=\(effectiveBottomInset) size=\(proxy.size.debugDescription)")
            }
    }
}
#endif

// PetWalkMapControls 地图浮动控件
// 核心职责：
// - 在地图上提供回到当前定位入口
// - 根据 sheet 展示状态和安全区域调整按钮位置
private struct PetWalkMapControls: View {
    let isSheetPresented: Bool
    let activeDetent: PresentationDetent
    let effectiveBottomInset: CGFloat
    let screenHeight: CGFloat
    let onRecenter: () -> Void

    var body: some View {
        let paddingBottom: CGFloat = {
            if isSheetPresented {
                if activeDetent == .medium {
                    // medium detent is approximately 45% of screen height
                    return screenHeight * 0.45 + 20
                } else {
                    // 260 height detent + safe area + offset (increased to 44 to clear rounded corners and top layout of sheet)
                    return 260 + effectiveBottomInset + 44
                }
            } else {
                // Collapsed entry height (84) + s5 padding (20) + safe area + offset (increased to 20)
                return 84 + MHBTheme.Spacing.s5 + effectiveBottomInset + 20
            }
        }()

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
                .padding(.bottom, paddingBottom)
            }
        }
        .animation(.spring(response: 0.36, dampingFraction: 0.86), value: paddingBottom)
        .accessibilityLabel("回到当前位置")
    }
}

// PetWalkTopChrome 遛弯页自绘顶部导航控件
// 核心职责：
// - 在系统导航栏位置展示返回按钮和记录状态
// - 避免系统导航栏背景参与地图页渲染
private struct PetWalkTopChrome: View {
    let phase: PetWalkSessionPhase
    let gpsStatusText: String
    let onBack: () -> Void

    var body: some View {
        GlassEffectContainer(spacing: MHBTheme.Spacing.s3) {
            ZStack {
                HStack {
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
                    .accessibilityIdentifier("pet.walkTracking.backButton")

                    Spacer(minLength: MHBTheme.Spacing.s4)

                    Color.clear
                        .frame(width: 48, height: 48)
                }

                PetWalkNavigationStatus(
                    phase: phase,
                    gpsStatusText: gpsStatusText
                )
                .padding(.horizontal, MHBTheme.Spacing.s4)
                .padding(.vertical, MHBTheme.Spacing.s2)
                .glassEffect(.regular.interactive(), in: .capsule)
                .accessibilityIdentifier("pet.walkTracking.navigationStatus")
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// PetWalkNavigationStatus 遛弯导航栏状态
// 核心职责：
// - 在顶部自绘导航区域展示当前记录状态
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
