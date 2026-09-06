import XCTest
@testable import PhonemeSynthesizer

final class MetricsTests: XCTestCase {
    func testEditDistance() {
        XCTAssertEqual(EditDistance.distance(["a", "b", "c"], ["a", "x", "c"]), 1)
        XCTAssertEqual(EditDistance.distance(["a", "b"], ["a", "b", "c"]), 1)
    }

    func testWERAndCER() {
        XCTAssertEqual(TextMetrics.wer(reference: "hello world", hypothesis: "hello there"), 0.5, accuracy: 0.0001)
        XCTAssertEqual(TextMetrics.cer(reference: "abc", hypothesis: "axc"), 1.0 / 3.0, accuracy: 0.0001)
    }

    func testErrorCountsSupportCorpusWeightedRates() {
        let words = TextMetrics.wordErrors(reference: "one two three four", hypothesis: "one two five four")
        XCTAssertEqual(words.edits, 1)
        XCTAssertEqual(words.referenceUnits, 4)
        XCTAssertEqual(words.rate, 0.25, accuracy: 0.0001)

        let chars = TextMetrics.characterErrors(reference: "abcd", hypothesis: "abxd")
        XCTAssertEqual(chars.edits, 1)
        XCTAssertEqual(chars.referenceUnits, 4)
    }

    func testSignalMetrics() {
        let m = SignalMetrics.measure(samples: [0, 0.5, -0.5, 1, -1])
        XCTAssertEqual(m.peak, 1, accuracy: 0.0001)
        XCTAssertEqual(m.clippingRatio, 0.4, accuracy: 0.0001)
        XCTAssertEqual(m.dcOffset, 0, accuracy: 0.0001)
        XCTAssertGreaterThan(m.rms, 0.6)
    }
}
