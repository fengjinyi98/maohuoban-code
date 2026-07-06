import XCTest

// NavigationArchitectureBoundaryTests 导航架构边界测试
// 核心职责：
// - 固化 Tab Root 统一注册导航目的地的约束
// - 防止可复用业务页面重新引入子级 navigationDestination
final class NavigationArchitectureBoundaryTests: XCTestCase {
    func testReusableFeatureScreensDoNotRegisterNestedNavigationDestinations() throws {
        let repositoryRoot = try Self.repositoryRoot()
        let disallowedFiles = [
            "maohuoban/maohuoban/Features/PetAlbum/Presentation/PetAlbumListScreen.swift",
            "maohuoban/maohuoban/Features/Topics/Presentation/TopicDetailScreen.swift",
            "maohuoban/maohuoban/Features/Topics/Presentation/TopicFollowedListScreen.swift"
        ]

        for relativePath in disallowedFiles {
            let source = try String(
                contentsOf: repositoryRoot.appendingPathComponent(relativePath),
                encoding: .utf8
            )
            XCTAssertFalse(
                source.contains(".navigationDestination(for:"),
                "\(relativePath) must delegate navigation to its owning Tab Root route."
            )
        }
    }

    func testProfileTabDoesNotRegisterSharedTopicRouteDirectly() throws {
        let repositoryRoot = try Self.repositoryRoot()
        let profileRootPath = repositoryRoot.appendingPathComponent(
            "maohuoban/maohuoban/Features/Profile/Presentation/ProfileRootScreen.swift"
        )
        let source = try String(contentsOf: profileRootPath, encoding: .utf8)

        XCTAssertFalse(
            source.contains(".navigationDestination(for: TopicRoute.self)"),
            "Profile Tab must map topic screens into ProfileRoute instead of registering TopicRoute directly."
        )
    }

    func testFollowedTopicsScreenUsesSystemLargeNavigationTitle() throws {
        let repositoryRoot = try Self.repositoryRoot()
        let sourcePath = repositoryRoot.appendingPathComponent(
            "maohuoban/maohuoban/Features/Topics/Presentation/TopicFollowedListScreen.swift"
        )
        let source = try String(contentsOf: sourcePath, encoding: .utf8)

        XCTAssertTrue(
            source.contains(".navigationTitle(\"我关注的话题\")"),
            "Followed topics screen must expose the title through the system navigation bar."
        )
        XCTAssertTrue(
            source.contains(".navigationBarTitleDisplayMode(.large)"),
            "Followed topics screen must use a large title so it collapses into the navigation bar on scroll."
        )
        XCTAssertFalse(
            source.contains(".navigationTitle(\"\")"),
            "Followed topics screen must not clear the system navigation title."
        )
    }

    func testInteractivePopGestureRestorerIsOnlyInstalledByRootTabStack() throws {
        let repositoryRoot = try Self.repositoryRoot()
        let allowedRelativePath = "maohuoban/maohuoban/App/Navigation/MHBRootTabStack.swift"
        let sourceRoot = repositoryRoot.appendingPathComponent("maohuoban/maohuoban")
        let swiftFiles = try FileManager.default.subpathsOfDirectory(atPath: sourceRoot.path)
            .filter { $0.hasSuffix(".swift") }
            .filter { $0 != "Infrastructure/UIKit/MHBInteractivePopGestureRestorer.swift" }

        for relativePath in swiftFiles {
            let fullPath = sourceRoot.appendingPathComponent(relativePath)
            let source = try String(contentsOf: fullPath, encoding: .utf8)
            let repositoryRelativePath = "maohuoban/maohuoban/\(relativePath)"

            if repositoryRelativePath == allowedRelativePath {
                XCTAssertTrue(
                    source.contains("MHBInteractivePopGestureRestorer()"),
                    "\(allowedRelativePath) must install the root pop gesture restorer."
                )
            } else {
                XCTAssertFalse(
                    source.contains("MHBInteractivePopGestureRestorer()"),
                    "\(repositoryRelativePath) must not install page-level pop gesture restorers."
                )
            }
        }
    }

    func testTabStateDoesNotExposeGenericRouteAppend() throws {
        let repositoryRoot = try Self.repositoryRoot()
        let tabStatePath = repositoryRoot.appendingPathComponent(
            "maohuoban/maohuoban/App/Navigation/MHBAppTabState.swift"
        )
        let source = try String(contentsOf: tabStatePath, encoding: .utf8)

        XCTAssertFalse(
            source.contains("func append<Route: Hashable>"),
            "Tab navigation state must expose typed append methods instead of accepting arbitrary Hashable routes."
        )
    }

    // testAbnormalRecordScreenKeepsSystemNavigation 固化异常记录页系统导航
    // 核心职责：
    // - 防止普通 push 页面隐藏系统导航栏和系统返回按钮
    // - 保留系统侧滑返回能力，避免导航转场期间多源更新
    func testAbnormalRecordScreenKeepsSystemNavigation() throws {
        let repositoryRoot = try Self.repositoryRoot()
        let sourcePath = repositoryRoot.appendingPathComponent(
            "maohuoban/maohuoban/Features/Pet/Presentation/Abnormal/Screens/PetAbnormalRecordScreen.swift"
        )
        let source = try String(contentsOf: sourcePath, encoding: .utf8)

        XCTAssertTrue(
            source.contains(".navigationTitle(\"异常\")"),
            "Abnormal record screen must expose title through the system navigation bar."
        )
        XCTAssertTrue(
            source.contains(".toolbar(.visible, for: .navigationBar)"),
            "Abnormal record screen must keep the system navigation bar visible."
        )
        XCTAssertFalse(
            source.contains(".toolbar(.hidden, for: .navigationBar)"),
            "Abnormal record screen must not hide the system navigation bar."
        )
        XCTAssertFalse(
            source.contains(".navigationBarBackButtonHidden(true)"),
            "Abnormal record screen must not hide the system back button."
        )
        XCTAssertFalse(
            source.contains("PetAbnormalRecordBackButton"),
            "Abnormal record screen must not reintroduce a custom back button for ordinary push navigation."
        )
    }

    // testPetSwitcherToolbarChromeAvoidsNestedLiquidGlass 固化系统导航栏宠物切换外观
    // 核心职责：
    // - 为通用宠物切换胶囊提供 toolbar 专用无 glass 模式
    // - 防止系统 toolbar 容器与组件自身 Liquid Glass 叠加
    func testPetSwitcherToolbarChromeAvoidsNestedLiquidGlass() throws {
        let repositoryRoot = try Self.repositoryRoot()
        let componentSourcePath = repositoryRoot.appendingPathComponent(
            "maohuoban/maohuoban/Infrastructure/SwiftUI/PetSwitcher/MHBPetSwitcherComponents.swift"
        )
        let abnormalToolbarSourcePath = repositoryRoot.appendingPathComponent(
            "maohuoban/maohuoban/Features/Pet/Presentation/Abnormal/Sections/PetAbnormalRecordTopChrome.swift"
        )
        let componentSource = try String(contentsOf: componentSourcePath, encoding: .utf8)
        let abnormalToolbarSource = try String(contentsOf: abnormalToolbarSourcePath, encoding: .utf8)

        XCTAssertTrue(
            componentSource.contains("enum MHBPetSwitcherCapsuleChrome"),
            "Pet switcher capsule must expose a chrome mode instead of forcing all call sites to use Liquid Glass."
        )
        XCTAssertTrue(
            componentSource.contains("case toolbar"),
            "Pet switcher capsule must provide a toolbar mode for system navigation toolbar usage."
        )
        XCTAssertTrue(
            componentSource.contains("MHBPetSwitcherCapsulePlainChrome"),
            "Toolbar mode must render through a plain chrome wrapper without applying glassEffect."
        )
        XCTAssertTrue(
            componentSource.contains(".glassEffect(.regular.interactive(), in: .capsule)"),
            "Default custom chrome mode must keep the existing Liquid Glass appearance."
        )
        XCTAssertTrue(
            abnormalToolbarSource.contains("chrome: .toolbar"),
            "System navigation toolbar pet switcher must use the plain toolbar chrome to avoid nested Liquid Glass containers."
        )
    }

    func testFeedInfrastructureUsesValueBasedNavigationOnly() throws {
        let repositoryRoot = try Self.repositoryRoot()
        let checkedFiles = [
            "maohuoban/maohuoban/Infrastructure/Feed/Presentation/Components/FeedCard.swift",
            "maohuoban/maohuoban/Infrastructure/Feed/Presentation/Components/FeedList.swift",
            "maohuoban/maohuoban/Features/Profile/Presentation/ProfilePostsScreen.swift"
        ]

        for relativePath in checkedFiles {
            let source = try String(
                contentsOf: repositoryRoot.appendingPathComponent(relativePath),
                encoding: .utf8
            )

            XCTAssertFalse(
                source.contains("onOpenDetail"),
                "\(relativePath) must use NavigationLink(value:) instead of a manual detail-opening callback."
            )
        }
    }

    // testSameCityRootUsesServiceMatrixInsteadOfTabs 固化同城根页首屏结构
    // 核心职责：
    // - 防止同城根页重新引入分类 tabs
    // - 确认同城根页保留金刚区与动态标题
    func testSameCityRootUsesServiceMatrixInsteadOfTabs() throws {
        let repositoryRoot = try Self.repositoryRoot()
        let sameCityRootPath = repositoryRoot.appendingPathComponent(
            "maohuoban/maohuoban/Features/SameCity/Presentation/SameCityRootScreen.swift"
        )
        let source = try String(contentsOf: sameCityRootPath, encoding: .utf8)

        XCTAssertFalse(
            source.contains("SameCityRootTabPicker"),
            "SameCity root must not render category tabs."
        )
        XCTAssertFalse(
            source.contains("MHBGlassSegmentedTabsBar"),
            "SameCity root must not use the segmented tabs infrastructure."
        )
        XCTAssertTrue(
            source.contains("SameCityServiceMatrix"),
            "SameCity root must render the service matrix."
        )
        XCTAssertTrue(
            source.contains("同城动态"),
            "SameCity root must expose the local feed title."
        )
    }

    private static func repositoryRoot() throws -> URL {
        var url = URL(fileURLWithPath: #filePath)
        while url.pathComponents.isEmpty == false {
            let candidate = url.appendingPathComponent("maohuoban/maohuoban.xcodeproj")
            if FileManager.default.fileExists(atPath: candidate.path) {
                return url
            }
            url.deleteLastPathComponent()
        }
        throw NSError(
            domain: "NavigationArchitectureBoundaryTests",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Unable to locate repository root."]
        )
    }
}
