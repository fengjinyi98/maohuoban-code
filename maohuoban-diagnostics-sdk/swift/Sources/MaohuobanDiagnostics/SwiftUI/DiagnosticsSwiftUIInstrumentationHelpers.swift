import Foundation

#if canImport(SwiftUI)
func componentLengthBucket(for valueLength: Int) -> String {
    switch valueLength {
    case 0:
        "empty"
    case 1...8:
        "short"
    case 9...32:
        "medium"
    case 33...128:
        "long"
    default:
        "very_long"
    }
}
#endif
