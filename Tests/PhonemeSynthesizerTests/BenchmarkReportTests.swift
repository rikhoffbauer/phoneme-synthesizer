import XCTest
@testable import PhonemeSynthesizer

final class BenchmarkReportTests: XCTestCase {
    func testJSONRoundTripKeepsNullableQualityMetrics() throws {
        let aggregate = BenchmarkAggregate(
            backend: "kokoro-ane", score: 98.0, wer: 0.01, cer: 0.002,
            utmos: nil, rtfx: 20.0, clippingRatio: 0.0, dcOffset: 0.0001)
        let report = BenchmarkReport(
            schemaVersion: 1,
            generatedAt: "2026-09-06T13:00:00Z",
            profile: "commit",
            benchmarkVersion: 1,
            git: .init(tree: "abc", branch: "main", commit: nil),
            system: .init(hardware: "Apple M4", os: "macOS", arch: "arm64"),
            corpus: .init(path: "commit.jsonl", sha256: "hash", samples: 1),
            aggregate: aggregate,
            gates: .init(passed: true, failures: []),
            backends: [], samples: [])
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(report)
        let json = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(json.contains("\"utmos\":null"), json)
        XCTAssertTrue(json.contains("\"commit\":null"), json)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let decoded = try decoder.decode(BenchmarkReport.self, from: data)
        XCTAssertEqual(decoded.schemaVersion, 1)
        XCTAssertEqual(decoded.aggregate.backend, "kokoro-ane")
        XCTAssertNil(decoded.aggregate.utmos)
    }

    func testScorePenalizesErrorsBeforeSpeed() {
        let excellent = BenchmarkScoring.score(wer: 0.01, cer: 0.002, utmos: 4.0, clippingRatio: 0, rtfx: 3)
        let fastButWrong = BenchmarkScoring.score(wer: 0.25, cer: 0.12, utmos: 4.5, clippingRatio: 0, rtfx: 100)
        XCTAssertGreaterThan(excellent, fastButWrong)
    }
}
