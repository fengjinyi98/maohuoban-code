import XCTest
@testable import maohuoban

final class PetProfileAddMediaRouteTests: XCTestCase {
    func testAvatarRouteUsesPickerWhenLocalAvatarIsMissing() {
        XCTAssertEqual(
            PetProfileAddMediaRoute.avatar(hasLocalAvatar: false),
            .picker
        )
    }

    func testAvatarRouteUsesPreviewWhenLocalAvatarExists() {
        XCTAssertEqual(
            PetProfileAddMediaRoute.avatar(hasLocalAvatar: true),
            .preview
        )
    }

    func testBackgroundRouteUsesPickerWhenLocalHeroMediaIsMissing() {
        XCTAssertEqual(
            PetProfileAddMediaRoute.background(hasLocalHeroMedia: false),
            .picker
        )
    }

    func testBackgroundRouteUsesPreviewWhenLocalHeroMediaExists() {
        XCTAssertEqual(
            PetProfileAddMediaRoute.background(hasLocalHeroMedia: true),
            .preview
        )
    }
}
