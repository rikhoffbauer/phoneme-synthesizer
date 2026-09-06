import Foundation
import FluidAudio

public struct BackendDescriptor: Codable, Sendable, Equatable {
    public let id: String
    public let displayName: String
    public let sampleRate: Int
    public let requiresReferenceAudio: Bool
    public let requiresPromptPhonemes: Bool

    public init(id: String, displayName: String, sampleRate: Int, requiresReferenceAudio: Bool, requiresPromptPhonemes: Bool) {
        self.id = id; self.displayName = displayName; self.sampleRate = sampleRate
        self.requiresReferenceAudio = requiresReferenceAudio
        self.requiresPromptPhonemes = requiresPromptPhonemes
    }
}

public struct SynthesisOptions: Sendable, Equatable {
    public var voice: String?
    public var speed: Float
    public var seed: UInt64
    public var referenceAudio: URL?
    public var promptPhonemes: String?

    public init(voice: String? = nil, speed: Float = 1, seed: UInt64 = 0, referenceAudio: URL? = nil, promptPhonemes: String? = nil) {
        self.voice = voice; self.speed = speed; self.seed = seed
        self.referenceAudio = referenceAudio; self.promptPhonemes = promptPhonemes
    }
}

public struct SynthesizedAudio: Sendable, Equatable {
    public let samples: [Float]
    public let sampleRate: Int
    public let backend: String
    public let metadata: [String: Double]

    public init(samples: [Float], sampleRate: Int, backend: String, metadata: [String: Double] = [:]) {
        self.samples = samples; self.sampleRate = sampleRate; self.backend = backend; self.metadata = metadata
    }

    public var durationSeconds: Double { Double(samples.count) / Double(sampleRate) }

    public func wavData() throws -> Data {
        try AudioWAV.data(from: samples, sampleRate: Double(sampleRate), normalize: false)
    }
}

public protocol PhonemeSynthesisBackend: Sendable {
    var descriptor: BackendDescriptor { get }
    func synthesize(_ input: IPAInput, options: SynthesisOptions) async throws -> SynthesizedAudio
}

public struct PhonemeSynthesizer: Sendable {
    private let backend: any PhonemeSynthesisBackend
    public init(backend: any PhonemeSynthesisBackend) { self.backend = backend }

    public func synthesize(ipa: String, options: SynthesisOptions = .init()) async throws -> SynthesizedAudio {
        try await backend.synthesize(IPAInput(ipa), options: options)
    }
}

public enum BackendCatalog {
    public static let descriptors: [BackendDescriptor] = [
        .init(id: "kokoro-ane", displayName: "Kokoro 82M ANE", sampleRate: 24_000, requiresReferenceAudio: false, requiresPromptPhonemes: false),
        .init(id: "luxtts", displayName: "LuxTTS / ZipVoice-Distill", sampleRate: 48_000, requiresReferenceAudio: true, requiresPromptPhonemes: true),
        .init(id: "styletts2", displayName: "StyleTTS2 LibriTTS", sampleRate: 24_000, requiresReferenceAudio: true, requiresPromptPhonemes: false),
        .init(id: "inflect-v2", displayName: "Inflect v2 Micro", sampleRate: 24_000, requiresReferenceAudio: false, requiresPromptPhonemes: false),
    ]

    public static func descriptor(id: String) -> BackendDescriptor? {
        descriptors.first { $0.id == id }
    }
}
