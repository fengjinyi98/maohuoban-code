import Foundation

func businessEvent(
    name: String,
    severity: DiagnosticSeverity = .info,
    metadata: DiagnosticProperties,
    extra: DiagnosticProperties
) -> DiagnosticEvent {
    DiagnosticEvent(
        kind: .analytics,
        severity: severity,
        message: name,
        metadata: metadata.merging(extra) { _, new in new }
    )
}

func durationMilliseconds(since date: Date) -> String {
    "\(max(0, Int(Date().timeIntervalSince(date) * 1_000)))"
}

func formBaseMetadata(
    form: String,
    field: String,
    screenName: String
) -> DiagnosticProperties {
    [
        "form": .string(form),
        "field": .string(field),
        "screen_name": .string(screenName)
    ]
}

func lengthBucket(for valueLength: Int) -> String {
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
