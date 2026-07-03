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

    func testPetPantryScreenUsesSpaceLevelTitleAndDietSummary() throws {
        let source = try sourceContents("Features/Pet/Presentation/Pantry/Screens/PetPantryScreen.swift")

        XCTAssertFalse(source.contains("\\(petName)的储物柜"))
        XCTAssertTrue(source.contains("家庭储物柜"))
        XCTAssertTrue(source.contains("PetPantryDietSummarySection"))
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

    func testPetPantryScreenDoesNotDefineProductionMockData() throws {
        let source = try sourceContents("Features/Pet/Presentation/Pantry/Screens/PetPantryScreen.swift")

        XCTAssertFalse(source.contains("enum PetPantryMockData"))
        XCTAssertFalse(source.contains("picsum.photos"))
    }

    func testPetPantryCategoryScreenExposesArchivedRestoreAction() throws {
        let source = try sourceContents("Features/Pet/Presentation/Pantry/Categories/PetPantryCategoryScreen.swift")

        XCTAssertTrue(source.contains("archivedPantryItems(for: category)"))
        XCTAssertTrue(source.contains("restoreItem("))
        XCTAssertTrue(source.contains("恢复到未拆封"))
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
