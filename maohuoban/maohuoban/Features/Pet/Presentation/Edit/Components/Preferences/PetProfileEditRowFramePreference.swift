import SwiftUI
import MaohuobanDesignSystem
import UIKit

enum PetProfileEditCoordinateSpace {
    static let name = "PetProfileEditScreen"
}

enum PetProfileEditRowAnchor: Hashable {
    case species
    case sex
    case neuterStatus
}

struct PetProfileEditRowFramePreferenceKey: PreferenceKey {
    static var defaultValue: [PetProfileEditRowAnchor: CGRect] = [:]

    static func reduce(
        value: inout [PetProfileEditRowAnchor: CGRect],
        nextValue: () -> [PetProfileEditRowAnchor: CGRect]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { _, newValue in newValue })
    }
}

extension View {
    func petProfileEditRowFrame(_ anchor: PetProfileEditRowAnchor) -> some View {
        background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: PetProfileEditRowFramePreferenceKey.self,
                    value: [anchor: proxy.frame(in: .named(PetProfileEditCoordinateSpace.name))]
                )
            }
        }
    }
}
