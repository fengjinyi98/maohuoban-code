import XCTest

// PetPantryScreenMockBoundaryTests 储物柜页面 Mock 边界测试
// 核心职责：
// - 防止真实储物柜首页继续暴露 Mock 演示操作
// - 固定 Phase2 真实数据路径不依赖本地演示菜单
final class PetPantryScreenMockBoundaryTests: XCTestCase {
    func testPetPantryScreenDoesNotExposeMockContextMenuActions() throws {
        let source = try String(contentsOfFile: petPantryScreenPath(), encoding: .utf8)

        XCTAssertFalse(source.contains("Mock 演示交互"))
        XCTAssertFalse(source.contains("删除储物柜"))
        XCTAssertFalse(source.contains(".contextMenu"))
    }

    func testPetPantryScreenUsesSpaceLevelTitleAndDietSummary() throws {
        let source = try String(contentsOfFile: petPantryScreenPath(), encoding: .utf8)

        XCTAssertFalse(source.contains("\\(petName)的储物柜"))
        XCTAssertTrue(source.contains("家庭储物柜"))
        XCTAssertTrue(source.contains("PetPantryDietSummarySection"))
    }

    func testPetPantryScreenDoesNotDefineProductionMockData() throws {
        let source = try String(contentsOfFile: petPantryScreenPath(), encoding: .utf8)

        XCTAssertFalse(source.contains("enum PetPantryMockData"))
        XCTAssertFalse(source.contains("picsum.photos"))
    }

    func testPetPantryCategoryScreenExposesArchivedRestoreAction() throws {
        let source = try String(contentsOfFile: petPantryCategoryScreenPath(), encoding: .utf8)

        XCTAssertTrue(source.contains("archivedPantryItems(for: category)"))
        XCTAssertTrue(source.contains("restoreItem("))
        XCTAssertTrue(source.contains("恢复到未拆封"))
    }

    func testPetPantryCategoryScreenExposesDietAssignmentActions() throws {
        let source = try String(contentsOfFile: petPantryCategoryScreenPath(), encoding: .utf8)
        let actionSheetSource = try String(
            contentsOfFile: sourcePath("Features/Pet/Presentation/Pantry/PantryItemActionSheet.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(source.contains("setCurrentStaple("))
        XCTAssertTrue(source.contains("setFoodAssignment("))
        XCTAssertTrue(actionSheetSource.contains("设为当前主粮"))
        XCTAssertTrue(actionSheetSource.contains("标记为尝试中"))
        XCTAssertTrue(actionSheetSource.contains("设为常用零食"))
        XCTAssertTrue(actionSheetSource.contains("设为常用营养品"))
        XCTAssertTrue(actionSheetSource.contains("设为不适合"))
        XCTAssertTrue(source.contains("role: .notSuitable"))
    }

    private func petPantryScreenPath() -> String {
        sourcePath("Features/Pet/Presentation/Pantry/PetPantryScreen.swift")
    }

    private func petPantryCategoryScreenPath() -> String {
        sourcePath("Features/Pet/Presentation/Pantry/PetPantryCategoryScreen.swift")
    }

    private func sourcePath(_ relativePath: String) -> String {
        let testFile = URL(fileURLWithPath: #filePath)
        let components = testFile.pathComponents
        guard let testsIndex = components.firstIndex(of: "maohuobanTests") else {
            return testFile.path
        }
        let projectRoot = URL(
            fileURLWithPath: components[..<testsIndex].joined(separator: "/")
        )
        return projectRoot
            .appendingPathComponent("maohuoban")
            .appendingPathComponent(relativePath)
            .path
    }
}
