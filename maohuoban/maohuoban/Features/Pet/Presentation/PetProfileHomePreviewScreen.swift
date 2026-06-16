import SwiftUI
import UIKit
import MaohuobanDesignSystem

// PetProfileHomePreviewContext 编辑档案首页预览上下文
// 核心职责：
// - 将编辑档案页的草稿展示值转换为首页首屏预览输入
// - 保持预览页与首页沉浸头图使用同源展示模型
struct PetProfileHomePreviewContext {
    let pet: HomeDashboardSnapshot.PetHeroSummary
    let displayName: String

    init(
        profile: PetProfileEditProfile,
        name: String,
        sexText: String,
        birthDateText: String,
        arrivalDateText: String,
        weightText: String,
        noteText: String
    ) {
        let heroMedia = Self.homeHeroMedia(from: profile.heroMedia)
        self.pet = HomeDashboardSnapshot.PetHeroSummary(
            id: profile.id,
            name: name,
            species: Self.homeSpecies(from: profile.species),
            breed: "",
            sex: Self.homeSex(sexText),
            ageText: "",
            statusText: noteText == "暂无" ? "档案预览中" : noteText,
            updatedText: "预览中",
            avatarURL: profile.avatarURL,
            heroImageAssetName: heroMedia.imageAssetName,
            heroVideoResourceName: heroMedia.videoResourceName,
            birthday: Self.normalizedDateText(birthDateText),
            companionshipDays: Self.daysSinceDateText(arrivalDateText),
            stats: Self.previewStats(weightText: weightText)
        )
        self.displayName = "你"
    }

    private static func homeSpecies(
        from species: PetProfileEditProfile.Species
    ) -> HomeDashboardSnapshot.Species {
        switch species {
        case .dog: .dog
        case .cat: .cat
        case .other: .other
        }
    }

    private static func homeSex(_ sexText: String) -> HomeDashboardSnapshot.Sex {
        switch sexText {
        case "公": .male
        case "母": .female
        default: .unknown
        }
    }

    private static func homeHeroMedia(
        from media: PetProfileEditProfile.HeroMedia
    ) -> (imageAssetName: String?, videoResourceName: String?) {
        switch media {
        case .image(let assetName):
            return (assetName, nil)
        case .video(let resourceName, let fileExtension, let fallbackImageAssetName):
            guard fileExtension.lowercased() == "mp4" else {
                return (fallbackImageAssetName, nil)
            }
            return (fallbackImageAssetName, resourceName)
        }
    }

    private static func normalizedDateText(_ dateText: String) -> String? {
        let trimmedDateText = dateText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedDateText.isEmpty == false,
              trimmedDateText != "暂未设置"
        else {
            return nil
        }

        return trimmedDateText
    }

    private static func daysSinceDateText(_ dateText: String) -> Int? {
        guard let date = date(from: dateText) else {
            return nil
        }

        let calendar = Calendar(identifier: .gregorian)
        let startDate = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: Date())

        return calendar.dateComponents([.day], from: startDate, to: today).day
    }

    private static func date(from dateText: String) -> Date? {
        guard let normalizedDateText = normalizedDateText(dateText) else {
            return nil
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)

        return formatter.date(from: normalizedDateText)
    }

    private static func previewStats(weightText: String) -> HomeDashboardSnapshot.PetHeroStats {
        HomeDashboardSnapshot.PetHeroStats(
            weightVal: normalizedWeightValue(from: weightText),
            weightChange: "当前档案",
            recordDays: 27,
            recordStreakText: "连续记录",
            vaccineDaysLeft: 14,
            vaccineDate: "2026.06.08",
            dewormingDaysLeft: 3,
            dewormingDate: "2026.05.28"
        )
    }

    private static func normalizedWeightValue(from weightText: String) -> String {
        let trimmedWeightText = weightText
            .replacingOccurrences(of: "kg", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmedWeightText.isEmpty == false,
              trimmedWeightText != "暂未记录",
              trimmedWeightText != "暂未设置"
        else {
            return "--"
        }

        return trimmedWeightText
    }
}

// PetProfileHomePreviewSession 编辑档案首页预览会话
// 核心职责：
// - 将预览内容、主题首帧和呈现标识绑定为同一个弹层输入
// - 避免系统弹层先创建空内容再补齐预览状态
struct PetProfileHomePreviewSession: Identifiable {
    let id: UUID
    let context: PetProfileHomePreviewContext
    let initialThemeSnapshot: HomeDashboardThemeSnapshot
    let heroImageWidth: CGFloat
    let topSafeAreaInset: CGFloat
}

// PetProfileHomePreviewScreen 编辑档案首页首屏预览页
// 核心职责：
// - 使用自定义全屏呈现当前宠物档案在首页首屏中的实时效果
// - 复用首页头图、取色和背景压暗能力，避免预览和真实首页视觉分叉
struct PetProfileHomePreviewScreen: View {
    let context: PetProfileHomePreviewContext
    let initialThemeSnapshot: HomeDashboardThemeSnapshot
    let topSafeAreaInset: CGFloat
    let onDismiss: () -> Void

    @State private var themeStore: HomeDashboardThemeStore
    @State private var scrollOffset: CGFloat = 0
    @State private var isThemeReady = true

    init(
        context: PetProfileHomePreviewContext,
        initialThemeSnapshot: HomeDashboardThemeSnapshot,
        topSafeAreaInset: CGFloat,
        onDismiss: @escaping () -> Void
    ) {
        self.context = context
        self.initialThemeSnapshot = initialThemeSnapshot
        self.topSafeAreaInset = topSafeAreaInset
        self.onDismiss = onDismiss
        _themeStore = State(initialValue: HomeDashboardThemeStore(snapshot: initialThemeSnapshot))
        _isThemeReady = State(initialValue: true)
    }

    private var backgroundColor: Color {
        guard isThemeReady else {
            return initialThemeSnapshot.backgroundColor(scrollProgress: 0)
        }

        return themeStore.backgroundColor(
            scrollProgress: Self.backgroundDimmingProgress(for: scrollOffset)
        )
    }

    var body: some View {
        GeometryReader { geometry in
            let heroImageWidth = max(geometry.size.width, 1)

            ZStack(alignment: .topTrailing) {
                backgroundColor
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: MHBTheme.Spacing.s4) {
                        HomeImmersivePetHeaderSection(
                            pet: context.pet,
                            displayName: context.displayName,
                            width: heroImageWidth,
                            fusionColor: backgroundColor,
                            contentColorScheme: themeStore.heroContentColorScheme,
                            scrollOffset: scrollOffset,
                            editProfileRoute: nil,
                            showsEditProfileButton: false
                        )

                        Color.clear
                            .frame(height: max(geometry.size.height - HomeImmersivePetHeaderLayout.imageHeight, 0))
                    }
                    .frame(maxWidth: .infinity)
                }
                .coordinateSpace(name: "petProfileHomePreviewScrollView")
                .ignoresSafeArea(edges: .top)
                .onScrollGeometryChange(for: CGFloat.self) { geometry in
                    geometry.contentOffset.y
                } action: { _, offset in
                    scrollOffset = max(offset, 0)
                }

                Button(action: onDismiss) {
                    HomeImmersiveHeaderCapsuleLabel(title: "退出预览")
                }
                .buttonStyle(.plain)
                .padding(.top, topSafeAreaInset + MHBTheme.Spacing.s1)
                .padding(.trailing, MHBTheme.Spacing.s4)
                .accessibilityLabel("关闭预览")
            }
            .task(id: themeUpdateID(width: heroImageWidth)) {
                await themeStore.update(
                    selectedPet: context.pet,
                    heroImageSize: CGSize(
                        width: heroImageWidth,
                        height: HomeImmersivePetHeaderLayout.backgroundDimmingReferenceHeight
                    )
                )
                isThemeReady = true
            }
        }
        .environment(\.colorScheme, .dark)
        .accessibilityIdentifier("pet.profileHomePreview.screen")
    }

    private func themeUpdateID(width: CGFloat) -> String {
        Self.themeUpdateID(context: context, width: width)
    }

    private static func themeUpdateID(context: PetProfileHomePreviewContext, width: CGFloat) -> String {
        switch context.pet.heroMedia {
        case .image(let assetName):
            "image-\(assetName)-\(Int(width.rounded()))"
        case .video(let resourceName, let fileExtension, _):
            "video-\(resourceName).\(fileExtension)-\(Int(width.rounded()))"
        }
    }

    private static var backgroundDimmingStartOffset: CGFloat {
        HomeImmersivePetHeaderLayout.backgroundDimmingReferenceHeight * 0.50
    }

    private static var backgroundDimmingEndOffset: CGFloat {
        HomeImmersivePetHeaderLayout.backgroundDimmingReferenceHeight
    }

    private static func backgroundDimmingProgress(for offset: CGFloat) -> CGFloat {
        let dimmingRange = max(backgroundDimmingEndOffset - backgroundDimmingStartOffset, 1)
        let rawProgress = (offset - backgroundDimmingStartOffset) / dimmingRange
        return min(max(rawProgress, 0), 1)
    }

}

// HomePreviewSafeAreaMetrics 首页预览安全区指标
// 核心职责：
// - 读取当前窗口顶部安全区，供 UIKit 自定义全屏预览的导航位控件定位
// - 将 UIKit 安全区访问隔离在预览呈现基础能力附近
enum HomePreviewSafeAreaMetrics {
    @MainActor
    static func currentWindowTopSafeAreaInset() -> CGFloat {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let keyWindow = scenes
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
        return keyWindow?.safeAreaInsets.top ?? 0
    }
}

// HomePreviewAnimatedPresentationContent 首页预览进入动画容器
// 核心职责：
// - 在 UIKit 无动画呈现后，为 SwiftUI 预览内容补齐全屏滑入动画
// - 避免系统 fullScreenCover 转场造成闪屏
struct HomePreviewAnimatedPresentationContent<Content: View>: View {
    @ViewBuilder let content: () -> Content
    @State private var isVisible = false

    var body: some View {
        GeometryReader { geometry in
            content()
                .offset(y: isVisible ? 0 : max(geometry.size.height, 1))
                .onAppear {
                    Task { @MainActor in
                        withAnimation(.interpolatingSpring(duration: 0.38, bounce: 0.04)) {
                            isVisible = true
                        }
                    }
                }
        }
        .ignoresSafeArea()
    }
}

// HomePreviewUIKitPresenter 首页预览 UIKit 呈现桥
// 核心职责：
// - 使用 UIKit 无动画呈现首页预览，绕开 fullScreenCover 默认转场
// - 保持 SwiftUI 预览内容、主题预热和关闭事件的单向数据流
struct HomePreviewUIKitPresenter<Content: View>: UIViewControllerRepresentable {
    let session: PetProfileHomePreviewSession?
    let onDidDismiss: () -> Void
    @ViewBuilder let content: (PetProfileHomePreviewSession) -> Content

    func makeUIViewController(context: Context) -> Controller {
        let controller = Controller()
        controller.coordinator = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: Controller, context: Context) {
        context.coordinator.session = session
        context.coordinator.onDidDismiss = onDidDismiss
        context.coordinator.content = content
        uiViewController.coordinator = context.coordinator

        context.coordinator.synchronizePresentation(from: uiViewController)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onDidDismiss: onDidDismiss, content: content)
    }

    final class Controller: UIViewController {
        var coordinator: Coordinator?

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            coordinator?.synchronizePresentation(from: self)
        }
    }

    final class Coordinator {
        var session: PetProfileHomePreviewSession?
        var onDidDismiss: () -> Void
        var content: (PetProfileHomePreviewSession) -> Content
        private var hostingController: UIHostingController<Content>?
        private var presentedSessionID: UUID?
        private var isTransitioning = false
        private let transitionDuration: TimeInterval = 0.34

        init(
            onDidDismiss: @escaping () -> Void,
            content: @escaping (PetProfileHomePreviewSession) -> Content
        ) {
            self.onDidDismiss = onDidDismiss
            self.content = content
        }

        @MainActor
        func synchronizePresentation(from presenter: UIViewController) {
            guard presenter.view.window != nil else {
                return
            }

            if let session {
                present(session: session, from: presenter)
            } else {
                dismissPresentedIfNeeded()
            }
        }

        @MainActor
        private func present(
            session: PetProfileHomePreviewSession,
            from presenter: UIViewController
        ) {
            if let hostingController,
               presentedSessionID == session.id {
                hostingController.rootView = content(session)
                return
            }

            guard !isTransitioning else {
                return
            }

            if hostingController != nil {
                dismissPresentedIfNeeded {
                    self.present(session: session, from: presenter)
                }
                return
            }

            let hostingController = UIHostingController(rootView: content(session))
            hostingController.modalPresentationStyle = .overFullScreen
            hostingController.modalTransitionStyle = .coverVertical
            hostingController.view.backgroundColor = .clear

            self.hostingController = hostingController
            presentedSessionID = session.id
            isTransitioning = true

            presenter.present(hostingController, animated: false) {
                self.isTransitioning = false
            }
        }

        @MainActor
        private func dismissPresentedIfNeeded(completion: (() -> Void)? = nil) {
            guard let hostingController else {
                completion?()
                return
            }

            isTransitioning = true

            UIView.animate(
                withDuration: transitionDuration * 0.86,
                delay: 0,
                options: [.curveEaseIn, .allowUserInteraction, .beginFromCurrentState]
            ) {
                hostingController.view.transform = CGAffineTransform(
                    translationX: 0,
                    y: max(hostingController.view.bounds.height, 1)
                )
            } completion: { _ in
                hostingController.dismiss(animated: false) {
                    self.hostingController = nil
                    self.presentedSessionID = nil
                    self.isTransitioning = false
                    self.onDidDismiss()
                    completion?()
                }
            }
        }
    }
}
