import Foundation

public enum EditDistance {
    public static func distance<T: Equatable>(_ lhs: [T], _ rhs: [T]) -> Int {
        if lhs.isEmpty { return rhs.count }
        if rhs.isEmpty { return lhs.count }
        var previous = Array(0...rhs.count)
        for (i, left) in lhs.enumerated() {
            var current = [i + 1] + Array(repeating: 0, count: rhs.count)
            for (j, right) in rhs.enumerated() {
                let substitution = previous[j] + (left == right ? 0 : 1)
                current[j + 1] = min(previous[j + 1] + 1, current[j] + 1, substitution)
            }
            previous = current
        }
        return previous[rhs.count]
    }
}

public struct ErrorRateMeasurement: Sendable, Equatable {
    public let edits: Int
    public let referenceUnits: Int
    public var rate: Double { referenceUnits == 0 ? (edits == 0 ? 0 : 1) : Double(edits) / Double(referenceUnits) }
}

public enum TextMetrics {
    public static func wordErrors(reference: String, hypothesis: String) -> ErrorRateMeasurement {
        let r = normalized(reference).split(separator: " ").map(String.init)
        let h = normalized(hypothesis).split(separator: " ").map(String.init)
        return .init(edits: EditDistance.distance(r, h), referenceUnits: r.count)
    }

    public static func characterErrors(reference: String, hypothesis: String) -> ErrorRateMeasurement {
        let r = Array(normalized(reference).replacingOccurrences(of: " ", with: "")).map(String.init)
        let h = Array(normalized(hypothesis).replacingOccurrences(of: " ", with: "")).map(String.init)
        return .init(edits: EditDistance.distance(r, h), referenceUnits: r.count)
    }

    public static func wer(reference: String, hypothesis: String) -> Double {
        wordErrors(reference: reference, hypothesis: hypothesis).rate
    }

    public static func cer(reference: String, hypothesis: String) -> Double {
        characterErrors(reference: reference, hypothesis: hypothesis).rate
    }

    private static func normalized(_ text: String) -> String {
        text.lowercased()
            .unicodeScalars
            .map { CharacterSet.alphanumerics.contains($0) || CharacterSet.whitespaces.contains($0) ? Character(String($0)) : " " }
            .reduce(into: "") { $0.append($1) }
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }
}

public struct SignalMeasurement: Codable, Sendable, Equatable {
    public let peak: Double
    public let rms: Double
    public let clippingRatio: Double
    public let dcOffset: Double
}

public enum SignalMetrics {
    public static func measure(samples: [Float]) -> SignalMeasurement {
        guard !samples.isEmpty else { return .init(peak: 0, rms: 0, clippingRatio: 0, dcOffset: 0) }
        let values = samples.map(Double.init)
        let peak = values.map(abs).max() ?? 0
        let rms = sqrt(values.reduce(0) { $0 + $1 * $1 } / Double(values.count))
        let clipping = Double(values.filter { abs($0) >= 0.999 }.count) / Double(values.count)
        let dc = values.reduce(0, +) / Double(values.count)
        return .init(peak: peak, rms: rms, clippingRatio: clipping, dcOffset: dc)
    }
}
