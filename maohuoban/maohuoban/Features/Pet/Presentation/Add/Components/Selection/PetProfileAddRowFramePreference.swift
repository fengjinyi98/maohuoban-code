import SwiftUI
import MaohuobanDesignSystem

enum PetProfileAddCoordinateSpace {
    static let name = "PetProfileAddScreen"
}

enum PetProfileAddRowAnchor: Hashable {
    case species
    case sex
    case neuterStatus
}

struct PetProfileAddRowFramePreferenceKey: PreferenceKey {
    static var defaultValue: [PetProfileAddRowAnchor: CGRect] = [:]

    static func reduce(
        value: inout [PetProfileAddRowAnchor: CGRect],
        nextValue: () -> [PetProfileAddRowAnchor: CGRect]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { _, newValue in newValue })
    }
}

extension View {
    func petProfileAddRowFrame(_ anchor: PetProfileAddRowAnchor) -> some View {
        background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: PetProfileAddRowFramePreferenceKey.self,
                    value: [anchor: proxy.frame(in: .named(PetProfileAddCoordinateSpace.name))]
                )
            }
        }
    }
}
