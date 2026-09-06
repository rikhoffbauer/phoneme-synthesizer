import XCTest
@testable import PhonemeSynthesizer

private actor FakeBackend: PhonemeSynthesisBackend {
    nonisolated let descriptor = BackendDescriptor(
        id: "fake", displayName: "Fake", sampleRate: 16_000,
        requiresReferenceAudio: false, requiresPromptPhonemes: false)

    func synthesize(_ input: IPAInput, options: SynthesisOptions) async throws -> SynthesizedAudio {
        SynthesizedAudio(samples: [0, 0.25, -0.25], sampleRate: 16_000, backend: descriptor.id)
    }
}

final class SynthesisTests: XCTestCase {
    func testServiceDelegatesDirectIPAWithoutTextConversion() async throws {
        let service = PhonemeSynthesizer(backend: FakeBackend())
        let audio = try await service.synthesize(ipa: "/həˈloʊ/")
        XCTAssertEqual(audio.backend, "fake")
        XCTAssertEqual(audio.sampleRate, 16_000)
        XCTAssertEqual(audio.samples, [0, 0.25, -0.25])
    }

    func testWavDataHasRiffHeaderAndKeepsNativeLevel() throws {
        let audio = SynthesizedAudio(samples: [0, 0.25, -0.25], sampleRate: 24_000, backend: "fake")
        let data = try audio.wavData()
        XCTAssertEqual(String(data: data.prefix(4), encoding: .ascii), "RIFF")
        XCTAssertEqual(String(data: data.dropFirst(8).prefix(4), encoding: .ascii), "WAVE")
    }

    func testCatalogExposesQualityCandidates() {
        XCTAssertEqual(Set(BackendCatalog.descriptors.map(\.id)), Set(["kokoro-ane", "luxtts", "styletts2", "inflect-v2"]))
        XCTAssertFalse(BackendCatalog.descriptor(id: "kokoro-ane")!.requiresReferenceAudio)
        XCTAssertTrue(BackendCatalog.descriptor(id: "luxtts")!.requiresReferenceAudio)
    }
}
