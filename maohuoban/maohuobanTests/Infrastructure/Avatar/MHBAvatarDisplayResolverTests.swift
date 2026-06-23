import XCTest
@testable import maohuoban

// MHBAvatarDisplayResolverTests 头像展示决策测试
// 核心职责：
// - 固化宠物 Feed 和评论头像优先展示人宠融合的规则
// - 固化宠物与用户头像描边的性别和隐私约束
final class MHBAvatarDisplayResolverTests: XCTestCase {
    func testFeedAuthorUsesCompositeAvatarWhenUserHasAnyPet() {
        let user = makeUser()
        let pet = makePet(id: "pet-1", name: "糯米", sex: .female)

        let subject = MHBAvatarDisplayResolver.feedAuthorSubject(
            user: user,
            pets: [pet],
            preferredPetID: nil
        )

        XCTAssertEqual(subject, .petWithUser(pet: pet, user: user))
    }

    func testFeedAuthorFallsBackToUserAvatarWhenUserHasNoPet() {
        let user = makeUser()

        let subject = MHBAvatarDisplayResolver.feedAuthorSubject(
            user: user,
            pets: [],
            preferredPetID: nil
        )

        XCTAssertEqual(subject, .user(user))
    }

    func testFeedAuthorUsesPreferredPetWhenUserHasMultiplePets() {
        let user = makeUser()
        let firstPet = makePet(id: "pet-1", name: "糯米", sex: .female)
        let preferredPet = makePet(id: "pet-2", name: "煤球", sex: .male)

        let subject = MHBAvatarDisplayResolver.feedAuthorSubject(
            user: user,
            pets: [firstPet, preferredPet],
            preferredPetID: "pet-2"
        )

        XCTAssertEqual(subject, .petWithUser(pet: preferredPet, user: user))
    }

    func testFeedAuthorUsesFirstPetWhenPreferredPetDoesNotExist() {
        let user = makeUser()
        let firstPet = makePet(id: "pet-1", name: "糯米", sex: .female)
        let secondPet = makePet(id: "pet-2", name: "煤球", sex: .male)

        let subject = MHBAvatarDisplayResolver.feedAuthorSubject(
            user: user,
            pets: [firstPet, secondPet],
            preferredPetID: "missing"
        )

        XCTAssertEqual(subject, .petWithUser(pet: firstPet, user: user))
    }

    func testPetBorderPaletteIsRequiredAndFollowsPetSex() {
        XCTAssertEqual(MHBAvatarBorderPalette.pet(sex: .male), .male)
        XCTAssertEqual(MHBAvatarBorderPalette.pet(sex: .female), .female)
        XCTAssertEqual(MHBAvatarBorderPalette.pet(sex: .unknown), .neutral)
    }

    func testUserBorderPaletteFollowsPrivacySetting() {
        XCTAssertEqual(
            MHBAvatarBorderPalette.user(sex: .female, sexVisibility: .visible),
            .female
        )
        XCTAssertEqual(
            MHBAvatarBorderPalette.user(sex: .female, sexVisibility: .hidden),
            .neutral
        )
        XCTAssertEqual(
            MHBAvatarBorderPalette.user(sex: .unknown, sexVisibility: .visible),
            .neutral
        )
    }

    func testAvatarShapeKeepsSquarePetAvatarAsSquircle() {
        XCTAssertEqual(
            MHBAvatarShape.circle.cornerRadius(for: 64),
            32,
            accuracy: 0.001
        )
        XCTAssertEqual(
            MHBAvatarShape.squircle.cornerRadius(for: 64),
            20,
            accuracy: 0.001
        )
    }

    func testCompositeAvatarOwnerBadgeScalesDownForCompactSizes() {
        XCTAssertEqual(
            MHBAvatarCompositeLayout.ownerAvatarSize(for: 28),
            17.36,
            accuracy: 0.001
        )
        XCTAssertEqual(
            MHBAvatarCompositeLayout.ownerAvatarSize(for: 56),
            24.64,
            accuracy: 0.001
        )
    }

    private func makeUser() -> MHBAvatarUser {
        MHBAvatarUser(
            id: "user-1",
            displayName: "林一",
            source: .asset("HomeUserAvatarMock"),
            sex: .female,
            sexVisibility: .visible
        )
    }

    private func makePet(id: String, name: String, sex: MHBAvatarSex) -> MHBAvatarPet {
        MHBAvatarPet(
            id: id,
            name: name,
            source: .asset("HomePetAlbum1"),
            species: .cat,
            sex: sex
        )
    }
}
