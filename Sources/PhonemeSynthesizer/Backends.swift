import Foundation
import FluidAudio

public enum BackendError: LocalizedError, Equatable {
    case unknownBackend(String)
    case missingReferenceAudio(String)
    case missingPromptPhonemes(String)
    case unsupportedSymbols(backend: String, symbols: [String])
    case unsupportedOption(String)

    public var errorDescription: String? {
        switch self {
        case .unknownBackend(let id): return "Unknown synthesis backend: \(id)"
        case .missingReferenceAudio(let id): return "Backend \(id) requires reference audio."
        case .missingPromptPhonemes(let id): return "Backend \(id) requires prompt phonemes."
        case .unsupportedSymbols(let backend, let symbols):
            return "Unsupported phoneme symbols for \(backend): \(symbols.joined(separator: " "))"
        case .unsupportedOption(let message): return message
        }
    }
}

private enum ScalarInventory {
    static let lux = Set("_^$ !'(),-.:;?abcdefhijklmnopqrstuvwxyzæçðøħŋœǀǁǂǃɐɑɒɓɔɕɖɗɘəɚɛɜɞɟɠɡɢɣɤɥɦɧɨɪɫɬɭɮɯɰɱɲɳɴɵɶɸɹɺɻɽɾʀʁʂʃʄʈʉʊʋʌʍʎʏʐʑʒʔʕʘʙʛʜʝʟʡʢʲˈˌːˑ˞βθχᵻⱱ0123456789̧̪̯̩̃ʰˤε↓#\"↑̺̻gʦX̝̊".unicodeScalars.map(String.init))
    static let inflect = Set("_;:,.!?¡¿—…\"«»“” ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyzɑɐɒæɓʙβɔɕçɗɖðʤəɘɚɛɜɝɞɟʄɡɠɢʛɦɧħɥʜɨɪʝɭɬɫɮʟɱɯɰŋɳɲɴøɵɸθœɶʘɹɺɾɻʀʁɽʂʃʈʧʉʊʋⱱʌɣɤʍχʎʏʑʐʒʔʡʕʢǀǁǂǃˈˌːˑʼʴʰʱʲʷˠˤ˞↓↑→↗↘'̩'ᵻ".unicodeScalars.map(String.init))

    static func validate(_ value: String, backend: String, against set: Set<String>) throws {
        let unsupported = Set(value.unicodeScalars.map(String.init).filter { !set.contains($0) }).sorted()
        if !unsupported.isEmpty { throw BackendError.unsupportedSymbols(backend: backend, symbols: unsupported) }
    }
}

public actor KokoroAneBackend: PhonemeSynthesisBackend {
    public nonisolated let descriptor = BackendCatalog.descriptor(id: "kokoro-ane")!
    private var manager: KokoroAneManager?

    public init() {}

    public func synthesize(_ input: IPAInput, options: SynthesisOptions) async throws -> SynthesizedAudio {
        try KokoroPhonemeInventory.validate(input.value)
        let manager = try await initializedManager(voice: options.voice)
        let result = try await manager.synthesizeFromPhonemesDetailed(
            input.value, voice: options.voice, speed: options.speed)
        return SynthesizedAudio(
            samples: result.samples, sampleRate: result.sampleRate, backend: descriptor.id,
            metadata: [
                "encoder_tokens": Double(result.encoderTokens),
                "acoustic_frames": Double(result.acousticFrames),
                "model_ms": result.timings.totalMs,
            ])
    }

    private func initializedManager(voice: String?) async throws -> KokoroAneManager {
        if let manager { return manager }
        let manager = KokoroAneManager(defaultVoice: voice)
        try await manager.initialize()
        self.manager = manager
        return manager
    }
}

public actor LuxTtsBackend: PhonemeSynthesisBackend {
    public nonisolated let descriptor = BackendCatalog.descriptor(id: "luxtts")!
    private var manager: LuxTtsManager?

    public init() {}

    public func synthesize(_ input: IPAInput, options: SynthesisOptions) async throws -> SynthesizedAudio {
        guard let referenceAudio = options.referenceAudio else {
            throw BackendError.missingReferenceAudio(descriptor.id)
        }
        guard let prompt = options.promptPhonemes, !prompt.isEmpty else {
            throw BackendError.missingPromptPhonemes(descriptor.id)
        }
        try ScalarInventory.validate(input.value, backend: descriptor.id, against: ScalarInventory.lux)
        try ScalarInventory.validate(prompt, backend: descriptor.id, against: ScalarInventory.lux)
        let manager = try await initializedManager()
        let result = try await manager.synthesize(
            phonemes: input.value, promptAudio: referenceAudio, promptPhonemes: prompt,
            speed: options.speed, seed: options.seed)
        return SynthesizedAudio(
            samples: result.samples, sampleRate: result.sampleRate, backend: descriptor.id,
            metadata: [
                "prompt_frames": Double(result.promptFrames),
                "generated_frames": Double(result.generatedFrames),
            ])
    }

    private func initializedManager() async throws -> LuxTtsManager {
        if let manager { return manager }
        let manager = try await LuxTtsManager.downloadAndCreate()
        self.manager = manager
        return manager
    }
}

public actor StyleTTS2Backend: PhonemeSynthesisBackend {
    public nonisolated let descriptor = BackendCatalog.descriptor(id: "styletts2")!
    private var manager: StyleTTS2Manager?

    public init() {}

    public func synthesize(_ input: IPAInput, options: SynthesisOptions) async throws -> SynthesizedAudio {
        guard let referenceAudio = options.referenceAudio else {
            throw BackendError.missingReferenceAudio(descriptor.id)
        }
        guard options.speed == 1 else {
            throw BackendError.unsupportedOption("StyleTTS2 does not expose a speech-rate control; use --speed 1.")
        }
        let unsupported = Set(input.value.filter { StyleTTS2TextCleaner.dictionary[$0] == nil }.map(String.init)).sorted()
        if !unsupported.isEmpty {
            throw BackendError.unsupportedSymbols(backend: descriptor.id, symbols: unsupported)
        }
        let manager = try await initializedManager()
        let samples = try await manager.synthesize(
            ipa: input.value, referenceAudioURL: referenceAudio, noiseSeed: options.seed)
        return SynthesizedAudio(samples: samples, sampleRate: StyleTTS2Constants.sampleRate, backend: descriptor.id)
    }

    private func initializedManager() async throws -> StyleTTS2Manager {
        if let manager { return manager }
        let manager = try await StyleTTS2Manager.downloadAndCreate()
        self.manager = manager
        return manager
    }
}

public actor InflectBackend: PhonemeSynthesisBackend {
    public nonisolated let descriptor = BackendCatalog.descriptor(id: "inflect-v2")!
    private var manager: InflectManager?
    private var speed: Float?

    public init() {}

    public func synthesize(_ input: IPAInput, options: SynthesisOptions) async throws -> SynthesizedAudio {
        try ScalarInventory.validate(input.value, backend: descriptor.id, against: ScalarInventory.inflect)
        let manager = try await initializedManager(speed: options.speed)
        let samples = try await manager.synthesize(ipa: input.value, noiseSeed: options.seed)
        return SynthesizedAudio(samples: samples, sampleRate: manager.sampleRate, backend: descriptor.id)
    }

    private func initializedManager(speed: Float) async throws -> InflectManager {
        if let manager, self.speed == speed { return manager }
        let manager = InflectManager(variant: .micro, speed: speed)
        try await manager.initialize()
        self.manager = manager
        self.speed = speed
        return manager
    }
}

public enum BackendFactory {
    public static func make(id: String) throws -> any PhonemeSynthesisBackend {
        switch id {
        case "kokoro-ane": return KokoroAneBackend()
        case "luxtts": return LuxTtsBackend()
        case "styletts2": return StyleTTS2Backend()
        case "inflect-v2": return InflectBackend()
        case "toucan-articulatory":
            return ToucanArticulatoryBackend(configuration: try .installedDefault())
        default: throw BackendError.unknownBackend(id)
        }
    }
}
