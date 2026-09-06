import Foundation
import PhonemeSynthesizer

@main
enum PhonemeSynthCLI {
    static func main() async {
        do { try await run() }
        catch {
            FileHandle.standardError.write(Data("error: \(error.localizedDescription)\n".utf8))
            exit(1)
        }
    }

    private static func run() async throws {
        var args = Array(CommandLine.arguments.dropFirst())
        let command = args.first ?? "help"
        if !args.isEmpty { args.removeFirst() }
        switch command {
        case "synth": try await synth(args)
        case "benchmark": try await benchmark(args)
        case "backends": listBackends()
        case "help", "--help", "-h": printHelp()
        default: throw CLIError.message("Unknown command: \(command)")
        }
    }

    private static func synth(_ args: [String]) async throws {
        let parsed = try Arguments(args)
        let ipa = try parsed.required("--ipa")
        let backendID = parsed.value("--backend") ?? "kokoro-ane"
        let output = URL(fileURLWithPath: parsed.value("--output") ?? "output.wav")
        let backend = try BackendFactory.make(id: backendID)
        let service = PhonemeSynthesizer(backend: backend)
        let options = SynthesisOptions(
            voice: parsed.value("--voice"),
            speed: Float(parsed.value("--speed") ?? "1") ?? 1,
            seed: UInt64(parsed.value("--seed") ?? "0") ?? 0,
            referenceAudio: parsed.value("--reference").map(URL.init(fileURLWithPath:)),
            promptPhonemes: parsed.value("--prompt-phonemes"))
        let audio = try await service.synthesize(ipa: ipa, options: options)
        try audio.wavData().write(to: output, options: .atomic)
        print("\(output.path)\t\(audio.sampleRate) Hz\t\(String(format: "%.3f", audio.durationSeconds)) s\t\(audio.backend)")
    }

    private static func benchmark(_ args: [String]) async throws {
        let parsed = try Arguments(args)
        let profile = parsed.value("--profile") ?? "commit"
        let corpus = URL(fileURLWithPath: parsed.value("--corpus") ?? "Benchmarks/corpus/commit.jsonl")
        let audioDir = URL(fileURLWithPath: parsed.value("--audio-dir") ?? ".benchmarks/audio")
        let output = URL(fileURLWithPath: parsed.value("--output-json") ?? ".benchmarks/latest.json")
        let synthesisOptions = SynthesisOptions(
            voice: parsed.value("--voice"),
            speed: Float(parsed.value("--speed") ?? "1") ?? 1,
            seed: UInt64(parsed.value("--seed") ?? "0") ?? 0,
            referenceAudio: parsed.value("--reference").map(URL.init(fileURLWithPath:)),
            promptPhonemes: parsed.value("--prompt-phonemes"))
        let report = try await BenchmarkRunner.run(.init(
            backendID: parsed.value("--backend") ?? "kokoro-ane",
            profile: profile, corpusURL: corpus, audioDirectory: audioDir,
            includeASR: !parsed.has("--skip-asr"), synthesisOptions: synthesisOptions))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(report)
        try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: output, options: .atomic)
        print("benchmark score \(String(format: "%.2f", report.aggregate.score)); output \(output.path)")
    }

    private static func listBackends() {
        for backend in BackendCatalog.descriptors {
            let conditioning = backend.requiresReferenceAudio ? "reference-conditioned" : "reference-free"
            print("\(backend.id)\t\(backend.sampleRate) Hz\t\(conditioning)\t\(backend.displayName)")
        }
    }

    private static func printHelp() {
        print("""
        phoneme-synth — direct phoneme/IPA speech synthesis

        Commands:
          synth --ipa <phones> [--backend kokoro-ane] [--output output.wav]
          benchmark [--profile commit] [--corpus file.jsonl] [--skip-asr]
          backends

        Conditioning options: --reference <audio> --prompt-phonemes <ipa>
        Synthesis options: --voice <name> --speed <factor> --seed <integer>
        """)
    }
}

private struct Arguments {
    let values: [String: String]
    let flags: Set<String>

    init(_ args: [String]) throws {
        var values: [String: String] = [:]
        var flags: Set<String> = []
        var i = 0
        while i < args.count {
            let key = args[i]
            guard key.hasPrefix("--") else { throw CLIError.message("Unexpected argument: \(key)") }
            if key == "--skip-asr" { flags.insert(key); i += 1; continue }
            guard i + 1 < args.count, !args[i + 1].hasPrefix("--") else {
                throw CLIError.message("Missing value for \(key)")
            }
            values[key] = args[i + 1]
            i += 2
        }
        self.values = values; self.flags = flags
    }

    func value(_ key: String) -> String? { values[key] }
    func has(_ key: String) -> Bool { flags.contains(key) }
    func required(_ key: String) throws -> String {
        guard let value = values[key] else { throw CLIError.message("Missing required option \(key)") }
        return value
    }
}

private enum CLIError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let value) = self { return value }; return nil }
}
