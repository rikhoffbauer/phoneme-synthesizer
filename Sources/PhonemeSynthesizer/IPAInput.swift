import Foundation

public enum IPAInputError: LocalizedError, Equatable {
    case empty

    public var errorDescription: String? {
        switch self {
        case .empty: return "Phoneme input is empty."
        }
    }
}

public struct IPAInput: Sendable, Equatable {
    public let value: String

    public init(_ rawValue: String) throws {
        var value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.count >= 2,
           let first = value.first,
           let last = value.last,
           (first == "/" && last == "/") || (first == "[" && last == "]")
        {
            value.removeFirst()
            value.removeLast()
            value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        value.unicodeScalars.removeAll { scalar in
            scalar.value == 0x200C || scalar.value == 0x200D || scalar.value == 0xFEFF
        }
        value = value.precomposedStringWithCanonicalMapping
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !value.isEmpty else { throw IPAInputError.empty }
        self.value = value
    }
}
