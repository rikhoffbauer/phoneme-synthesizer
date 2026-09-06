import Foundation
import XCTest
@testable import PhonemeSynthesizer

final class ToucanBackendTests: XCTestCase {
    func testCanonicalizesKnownRhoticFormsWithoutDroppingContrast() throws {
        XCTAssertEqual(
            try ToucanIPAAdapter.canonicalize("ə˞ ɜ˞ ɚ ɝ"),
            "əɹ ɜɹ əɹ ɜɹ"
        )
    }

    func testCollapsesSecondaryStressToToucanBinaryStressFeature() throws {
        XCTAssertEqual(try ToucanIPAAdapter.canonicalize("ɐbˌaʊt"), "ɐbˈaʊt")
    }

    func testCanonicalizesExactToucanArticulatoryAliases() throws {
        XCTAssertEqual(try ToucanIPAAdapter.canonicalize("tʲ kˤ ɥ ⱱ"), "ţ kˁ jʷ ѵ")
    }

    func testRejectsRhoticityWhenNoDefensibleDecompositionExists() {
        XCTAssertThrowsError(try ToucanIPAAdapter.canonicalize("a˞")) { error in
            XCTAssertEqual(
                error as? BackendError,
                .unsupportedSymbols(backend: "toucan-articulatory", symbols: ["˞"])
            )
        }
    }

    func testCatalogIncludesArticulatoryBackend() {
        let descriptor = BackendCatalog.descriptor(id: "toucan-articulatory")
        XCTAssertEqual(descriptor?.sampleRate, 24_000)
        XCTAssertEqual(descriptor?.requiresReferenceAudio, false)
    }

    func testBackendReusesOneWorkerAcrossSynthesisRequests() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let starts = dir.appendingPathComponent("starts.txt")
        let script = dir.appendingPathComponent("fake_worker.py")
        let python = #"""
import json, struct, sys, wave
open(\#(starts.path.debugDescription), "a").write("start\\n")
print(json.dumps({"ready": True, "sample_rate": 24000}), flush=True)
for line in sys.stdin:
    req = json.loads(line)
    with wave.open(req["output"], "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(24000)
        w.writeframes(struct.pack("<hhh", 0, 8192, -8192))
    print(json.dumps({"id": req["id"], "ok": True, "sample_rate": 24000,
                      "synthesis_seconds": 0.01}), flush=True)
"""#
        try python.write(to: script, atomically: true, encoding: .utf8)

        let config = ToucanWorkerConfiguration(
            pythonExecutable: URL(fileURLWithPath: "/usr/bin/python3"),
            workerScript: script,
            toucanRepository: dir
        )
        let backend = ToucanArticulatoryBackend(configuration: config)
        let first = try await backend.synthesize(IPAInput("kʰæ̃n"), options: .init())
        let second = try await backend.synthesize(IPAInput("kʰæ̃n"), options: .init())
        XCTAssertEqual(first.sampleRate, 24_000)
        XCTAssertEqual(first.samples.count, 3)
        XCTAssertEqual(second.samples.count, 3)
        XCTAssertEqual(try String(contentsOf: starts).split(separator: "\\n").count, 1)
    }
    func testFactoryCreatesToucanBackendWithoutStartingWorker() throws {
        let backend = try BackendFactory.make(id: "toucan-articulatory")
        XCTAssertEqual(backend.descriptor.id, "toucan-articulatory")
    }

    func testMissingInstallReportsSetupCommand() async {
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let config = ToucanWorkerConfiguration(
            pythonExecutable: missing.appendingPathComponent("python"),
            workerScript: missing.appendingPathComponent("worker.py"),
            toucanRepository: missing.appendingPathComponent("repo")
        )
        let backend = ToucanArticulatoryBackend(configuration: config)
        do {
            _ = try await backend.synthesize(IPAInput("ka"), options: .init())
            XCTFail("expected missing-install error")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("toucan:setup"), error.localizedDescription)
        }
    }

}
