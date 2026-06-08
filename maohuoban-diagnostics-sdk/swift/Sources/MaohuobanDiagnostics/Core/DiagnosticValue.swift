import Foundation

// DiagnosticValue 结构化诊断属性值
// 核心职责：
// - 表达可写入事件 metadata 的 JSON 兼容值
// - 保持 Swift 与 Rust 诊断协议的属性表达能力一致
public enum DiagnosticValue: Codable, Equatable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([DiagnosticValue])
    case object([String: DiagnosticValue])
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([DiagnosticValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: DiagnosticValue].self) {
            self = .object(value)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported diagnostic value"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .string(value):
            try container.encode(value)
        case let .int(value):
            try container.encode(value)
        case let .double(value):
            try container.encode(value)
        case let .bool(value):
            try container.encode(value)
        case let .array(value):
            try container.encode(value)
        case let .object(value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}

extension DiagnosticValue: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

extension DiagnosticValue: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self = .int(value)
    }
}

extension DiagnosticValue: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self = .double(value)
    }
}

extension DiagnosticValue: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self = .bool(value)
    }
}

extension DiagnosticValue: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: DiagnosticValue...) {
        self = .array(elements)
    }
}

extension DiagnosticValue: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, DiagnosticValue)...) {
        self = .object(Dictionary(uniqueKeysWithValues: elements))
    }
}

extension DiagnosticValue {
    public var stringValue: String? {
        guard case let .string(value) = self else {
            return nil
        }
        return value
    }

    public var isEmpty: Bool {
        stringValue?.isEmpty ?? false
    }

    public func contains(_ other: String) -> Bool {
        stringValue?.contains(other) ?? false
    }

    public func hasSuffix(_ suffix: String) -> Bool {
        stringValue?.hasSuffix(suffix) ?? false
    }

    func applyingToStrings(_ transform: (String) -> String) -> DiagnosticValue {
        switch self {
        case let .string(value):
            .string(transform(value))
        case let .array(values):
            .array(values.map { $0.applyingToStrings(transform) })
        case let .object(values):
            .object(values.mapValues { $0.applyingToStrings(transform) })
        case .int, .double, .bool, .null:
            self
        }
    }

    func truncatingStrings(to limit: Int) -> DiagnosticValue {
        applyingToStrings { value in
            guard limit >= 0, value.count > limit else {
                return value
            }
            return String(value.prefix(limit)) + "..."
        }
    }
}

public typealias DiagnosticProperties = [String: DiagnosticValue]

public func == (lhs: DiagnosticValue?, rhs: String) -> Bool {
    lhs?.stringValue == rhs
}

public func == (lhs: String, rhs: DiagnosticValue?) -> Bool {
    rhs == lhs
}

public func == (lhs: DiagnosticValue?, rhs: Int) -> Bool {
    lhs == .int(rhs)
}

public func == (lhs: Int, rhs: DiagnosticValue?) -> Bool {
    rhs == lhs
}

public func == (lhs: DiagnosticValue?, rhs: Double) -> Bool {
    lhs == .double(rhs)
}

public func == (lhs: Double, rhs: DiagnosticValue?) -> Bool {
    rhs == lhs
}

public func == (lhs: DiagnosticValue?, rhs: Bool) -> Bool {
    lhs == .bool(rhs)
}

public func == (lhs: Bool, rhs: DiagnosticValue?) -> Bool {
    rhs == lhs
}
