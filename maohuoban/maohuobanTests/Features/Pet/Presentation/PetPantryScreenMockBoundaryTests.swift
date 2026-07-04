import XCTest
@testable import maohuoban

// PetPantryScreenMockBoundaryTests 储物柜页面 Mock 边界测试
// 核心职责：
// - 防止真实储物柜首页继续暴露 Mock 演示操作
// - 固定 Phase2 真实数据路径不依赖本地演示菜单
final class PetPantryScreenMockBoundaryTests: XCTestCase {
    func testPetPantryScreenDoesNotExposeMockContextMenuActions() throws {
        let source = try sourceContents("Features/Pet/Presentation/Pantry/Screens/PetPantryScreen.swift")

        XCTAssertFalse(source.contains("Mock 演示交互"))
        XCTAssertFalse(source.contains("删除储物柜"))
        XCTAssertFalse(source.contains(".contextMenu"))
    }

    func testPetPantryScreenUsesSpaceLevelTitleOnly() throws {
        let source = try sourceContents("Features/Pet/Presentation/Pantry/Screens/PetPantryScreen.swift")

        XCTAssertFalse(source.contains("\\(petName)的储物柜"))
        XCTAssertTrue(source.contains("家庭储物柜"))
        XCTAssertFalse(source.contains("PetPantryDietSummarySection"))
        XCTAssertFalse(source.contains("PetPantryDietTrendSection"))
        XCTAssertFalse(source.contains("store.dietTrendSummary"))
    }

    func testHomeDashboardRendersDietTrendBeforePantrySection() throws {
        let dashboardSource = try sourceContents("Features/Home/Presentation/Sections/Dashboard/HomeDashboardContentSections.swift")
        let trendIndex = try XCTUnwrap(dashboardSource.range(of: "HomeDietTrendSection")?.lowerBound)
        let pantryIndex = try XCTUnwrap(dashboardSource.range(of: "HomePantrySection")?.lowerBound)

        XCTAssertLessThan(trendIndex, pantryIndex)
        XCTAssertTrue(dashboardSource.contains("snapshot.dietTrendSummary"))
    }

    @MainActor
    func testPetPantryScreensAcceptEntryContextAtCompileTime() {
        let context = PetPantryEntryContext(sourcePetID: "pet-1", sourcePetName: "糯米")

        _ = PetPantryScreen<PetPantryRoute>(
            context: context,
            currentUserID: nil,
            onNavigate: { $0 }
        )
        _ = PetPantryCategoryScreen<PetPantryRoute>(
            context: context,
            category: .mainFood,
            currentUserID: nil,
            onNavigate: { $0 }
        )
    }

    @MainActor
    func testPantryItemFormUsesSingleScreenForCreateAndEditModesAtCompileTime() {
        let item = PantryItem(
            id: "item-1",
            name: "主粮",
            brand: "品牌",
            coverAssetID: "asset-1",
            imageURL: "/media/asset-1.jpg",
            category: .mainFood,
            status: .sealed,
            statusDate: "2026-07-04",
            statusLabel: "# 未拆封囤货",
            quantity: 1,
            unit: "件",
            spec: "5kg",
            expiryDate: "2027-07-04"
        )

        _ = AddPantryItemScreen(mode: .create, currentUserID: "user-1")
        _ = AddPantryItemScreen(mode: .edit(item), currentUserID: "user-1")
    }

    func testPetPantryScreenDoesNotDefineProductionMockData() throws {
        let source = try sourceContents("Features/Pet/Presentation/Pantry/Screens/PetPantryScreen.swift")

        XCTAssertFalse(source.contains("enum PetPantryMockData"))
        XCTAssertFalse(source.contains("picsum.photos"))
    }

    func testPetPantryCategoryScreenDoesNotExposeArchivedRestoreAction() throws {
        let source = try sourceContents("Features/Pet/Presentation/Pantry/Categories/PetPantryCategoryScreen.swift")

        XCTAssertFalse(source.contains("archivedPantryItems(for: category)"))
        XCTAssertFalse(source.contains("restoreItem("))
        XCTAssertFalse(source.contains("恢复到未拆封"))
        XCTAssertFalse(source.contains("已归档"))
    }

    func testPetPantryItemActionSheetUsesDeleteCopyAndItemInformationCopy() throws {
        let categorySource = try sourceContents("Features/Pet/Presentation/Pantry/Categories/PetPantryCategoryScreen.swift")
        let actionSheetSource = try sourceContents("Features/Pet/Presentation/Pantry/Items/PantryItemActionSheet.swift")

        XCTAssertTrue(categorySource.contains("store.deleteItem("))
        XCTAssertTrue(actionSheetSource.contains("编辑物品信息"))
        XCTAssertTrue(actionSheetSource.contains("移出储物柜"))
        XCTAssertTrue(actionSheetSource.contains("onDelete"))
        XCTAssertFalse(actionSheetSource.contains("编辑物品档案"))
        XCTAssertFalse(actionSheetSource.contains("onArchive"))
    }

    func testPetPantryItemEditUsesPushFormAndImmediateCoverUploadBoundary() throws {
        let categorySource = try sourceContents("Features/Pet/Presentation/Pantry/Categories/PetPantryCategoryScreen.swift")
        let addSource = try sourceContents("Features/Pet/Presentation/Pantry/Screens/AddPantryItemScreen.swift")
        let destinationSource = try sourceContents("Features/Home/Presentation/Navigation/HomeRouteDestinationScreen.swift")

        XCTAssertFalse(categorySource.contains("@State private var editingItem"))
        XCTAssertFalse(categorySource.contains(".sheet(item: $editingItem)"))
        XCTAssertTrue(categorySource.contains("onOpenRoute(onNavigate(.editItem(item)))"))

        XCTAssertTrue(destinationSource.contains("mode: .create"))
        XCTAssertTrue(destinationSource.contains("mode: .edit(item)"))
        XCTAssertTrue(addSource.contains("store.createItem("))
        XCTAssertTrue(addSource.contains("store.updateItem("))
        XCTAssertTrue(addSource.contains("store.uploadCover("))
        XCTAssertTrue(addSource.contains("draft.coverAssetID = result.asset.id"))
        XCTAssertFalse(addSource.contains("coverUploadDraft:"))
    }

    func testPetPantryCategoryScreenExposesDietAssignmentActions() throws {
        let source = try sourceContents("Features/Pet/Presentation/Pantry/Categories/PetPantryCategoryScreen.swift")
        let actionSheetSource = try sourceContents("Features/Pet/Presentation/Pantry/Items/PantryItemActionSheet.swift")

        XCTAssertTrue(source.contains("setCurrentStaple("))
        XCTAssertTrue(source.contains("setFoodAssignment("))
        XCTAssertTrue(actionSheetSource.contains("设为当前主粮"))
        XCTAssertTrue(actionSheetSource.contains("标记为尝试中"))
        XCTAssertTrue(actionSheetSource.contains("设为常用零食"))
        XCTAssertTrue(actionSheetSource.contains("设为常用营养品"))
        XCTAssertTrue(actionSheetSource.contains("设为不适合"))
        XCTAssertTrue(source.contains("role: .notSuitable"))
    }

    func testHomePantryPreviewCardsRouteOnlyToCategoryDetail() throws {
        let homeSectionSource = try sourceContents("Features/Home/Presentation/Sections/Pet/Care/HomePantrySection.swift")
        let dashboardSource = try sourceContents("Features/Home/Presentation/Sections/Dashboard/HomeDashboardContentSections.swift")
        let categorySource = try sourceContents("Features/Pet/Presentation/Pantry/Categories/PetPantryCategoryScreen.swift")

        XCTAssertTrue(homeSectionSource.contains("NavigationLink(value: cardRoute(item))"))
        XCTAssertTrue(dashboardSource.contains("category: item.pantryCategory"))
        XCTAssertFalse(dashboardSource.contains("initialItemID: item.id"))
        XCTAssertFalse(categorySource.contains("initialSelectedItemID"))
        XCTAssertFalse(categorySource.contains("applyInitialSelectionIfNeeded()"))
    }

    func testHomePantrySectionHeaderUsesAllCategoriesAction() throws {
        let homeSectionSource = try sourceContents("Features/Home/Presentation/Sections/Pet/Care/HomePantrySection.swift")

        XCTAssertTrue(homeSectionSource.contains("Text(\"储物柜\")"))
        XCTAssertTrue(homeSectionSource.contains("Text(\"全部分类\")"))
        XCTAssertTrue(homeSectionSource.contains("Image(systemName: \"chevron.right\")"))
    }

    func testHomeGallerySectionHeaderUsesAllAlbumsAction() throws {
        let gallerySectionSource = try sourceContents("Features/Home/Presentation/Sections/Pet/Media/Gallery/HomePetGallerySection.swift")

        XCTAssertTrue(gallerySectionSource.contains("Text(\"相册\")"))
        XCTAssertTrue(gallerySectionSource.contains("Text(\"全部相册\")"))
        XCTAssertTrue(gallerySectionSource.contains("Image(systemName: \"chevron.right\")"))
    }

    func testHomeGalleryCardsRouteToAlbumDetail() throws {
        let gallerySectionSource = try sourceContents("Features/Home/Presentation/Sections/Pet/Media/Gallery/HomePetGallerySection.swift")
        let dashboardSource = try sourceContents("Features/Home/Presentation/Sections/Dashboard/HomeDashboardContentSections.swift")
        let albumModelSource = try sourceContents("Features/Home/Domain/Models/Sections/HomeDashboardSections.swift")

        XCTAssertTrue(gallerySectionSource.contains("NavigationLink(value: cardRoute(album))"))
        XCTAssertTrue(dashboardSource.contains("destination: .detail(album.petAlbumSummary("))
        XCTAssertTrue(albumModelSource.contains("func petAlbumSummary("))
    }

    func testPantryItemCardRendersCoverImageFlush() throws {
        let source = try sourceContents("Features/Pet/Presentation/Pantry/Items/PantryItemCard.swift")

        XCTAssertFalse(source.contains("private var coverGradient"))
        XCTAssertFalse(source.contains("private var coverColors"))
        XCTAssertFalse(source.contains(".aspectRatio(contentMode: .fit)"))
        XCTAssertTrue(source.contains(".aspectRatio(contentMode: .fill)"))
    }

    func testPantryItemActionSheetRendersThumbnailFlush() throws {
        let source = try sourceContents("Features/Pet/Presentation/Pantry/Items/PantryItemActionSheet.swift")

        XCTAssertFalse(source.contains("LinearGradient("))
        XCTAssertFalse(source.contains(".aspectRatio(contentMode: .fit)"))
        XCTAssertFalse(source.contains(".frame(width: 42, height: 42)"))
        XCTAssertTrue(source.contains(".aspectRatio(contentMode: .fill)"))
    }

    private func sourceContents(_ relativePath: String) throws -> String {
        let path = sourcePath(relativePath)
        guard FileManager.default.fileExists(atPath: path) else {
            throw XCTSkip("源码文件在当前测试宿主不可访问: \(relativePath)")
        }
        return try String(contentsOfFile: path, encoding: .utf8)
    }

    private func sourcePath(_ relativePath: String) -> String {
        let testFile = URL(fileURLWithPath: #filePath)
        let components = testFile.pathComponents
        guard let testsIndex = components.firstIndex(of: "maohuobanTests") else {
            return testFile.path
        }
        let projectRoot = URL(
            fileURLWithPath: "/" + components[..<testsIndex].dropFirst().joined(separator: "/")
        )
        return projectRoot
            .appendingPathComponent("maohuoban")
            .appendingPathComponent(relativePath)
            .path
    }
}
