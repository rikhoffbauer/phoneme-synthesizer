import CryptoKit
import Foundation
import FluidAudio

public struct BenchmarkCorpusItem: Codable, Sendable, Equatable {
    public let id: String
    public let text: String
    public let ipa: String

    public init(id: String, text: String, ipa: String) {
        self.id = id; self.text = text; self.ipa = ipa
    }
}

public struct BenchmarkRunOptions: Sendable {
    public var backendID: String
    public var profile: String
    public var corpusURL: URL
    public var audioDirectory: URL
    public var includeASR: Bool
    public var synthesisOptions: SynthesisOptions

    public init(
        backendID: String = "kokoro-ane",
        profile: String = "commit",
        corpusURL: URL,
        audioDirectory: URL,
        includeASR: Bool = true,
        synthesisOptions: SynthesisOptions = .init()
    ) {
        self.backendID = backendID
        self.profile = profile
        self.corpusURL = corpusURL
        self.audioDirectory = audioDirectory
        self.includeASR = includeASR
        self.synthesisOptions = synthesisOptions
    }
}

public enum BenchmarkRunnerError: LocalizedError {
    case invalidCorpusLine(Int, String)
    case emptyCorpus

    public var errorDescription: String? {
        switch self {
        case .invalidCorpusLine(let line, let detail): return "Invalid benchmark corpus line \(line): \(detail)"
        case .emptyCorpus: return "Benchmark corpus is empty."
        }
    }
}

public enum BenchmarkRunner {
    public static func loadCorpus(_ url: URL) throws -> [BenchmarkCorpusItem] {
        let contents = try String(contentsOf: url, encoding: .utf8)
        let decoder = JSONDecoder()
        var items: [BenchmarkCorpusItem] = []
        for (index, raw) in contents.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty || line.hasPrefix("#") { continue }
            guard let data = line.data(using: .utf8) else {
                throw BenchmarkRunnerError.invalidCorpusLine(index + 1, "not UTF-8")
            }
            do { items.append(try decoder.decode(BenchmarkCorpusItem.self, from: data)) }
            catch { throw BenchmarkRunnerError.invalidCorpusLine(index + 1, error.localizedDescription) }
        }
        guard !items.isEmpty else { throw BenchmarkRunnerError.emptyCorpus }
        return items
    }

    public static func run(_ options: BenchmarkRunOptions) async throws -> BenchmarkReport {
        let items = try loadCorpus(options.corpusURL)
        let backend = try BackendFactory.make(id: options.backendID)
        let service = PhonemeSynthesizer(backend: backend)
        try FileManager.default.createDirectory(at: options.audioDirectory, withIntermediateDirectories: true)

        // Warm model loading/compilation outside timed samples.
        _ = try await service.synthesize(ipa: items[0].ipa, options: options.synthesisOptions)

        let asr = try await options.includeASR ? makeASR() : nil
        var sampleResults: [BenchmarkSampleResult] = []
        var totalSynthMs = 0.0
        var totalAudioMs = 0.0
        var wordEdits = 0
        var referenceWords = 0
        var characterEdits = 0
        var referenceCharacters = 0
        var clipping: [Double] = []
        var dcOffsets: [Double] = []

        for (index, item) in items.enumerated() {
            var synthOptions = options.synthesisOptions
            synthOptions.seed = options.synthesisOptions.seed &+ UInt64(index)
            let start = ContinuousClock.now
            let audio = try await service.synthesize(ipa: item.ipa, options: synthOptions)
            let elapsed = start.duration(to: ContinuousClock.now)
            let synthMs = elapsed.seconds * 1_000
            let audioMs = audio.durationSeconds * 1_000
            let rtfx = synthMs > 0 ? audioMs / synthMs : 0
            let signal = SignalMetrics.measure(samples: audio.samples)

            let safeID = item.id.replacingOccurrences(of: "/", with: "-")
            let fileName = "\(String(format: "%02d", index + 1))-\(safeID).wav"
            let audioURL = options.audioDirectory.appendingPathComponent(fileName)
            try audio.wavData().write(to: audioURL, options: .atomic)

            var wer: Double? = nil
            var cer: Double? = nil
            if let asr {
                let converter = AudioConverter(sampleRate: 16_000)
                let samples16k = try converter.resample(audio.samples, from: Double(audio.sampleRate))
                var state = try TdtDecoderState(decoderLayers: await asr.decoderLayerCount)
                let result = try await asr.transcribe(samples16k, decoderState: &state)
                let wordErrors = TextMetrics.wordErrors(reference: item.text, hypothesis: result.text)
                let characterErrors = TextMetrics.characterErrors(reference: item.text, hypothesis: result.text)
                wer = wordErrors.rate
                cer = characterErrors.rate
                wordEdits += wordErrors.edits
                referenceWords += wordErrors.referenceUnits
                characterEdits += characterErrors.edits
                referenceCharacters += characterErrors.referenceUnits
            }

            totalSynthMs += synthMs
            totalAudioMs += audioMs
            clipping.append(signal.clippingRatio)
            dcOffsets.append(signal.dcOffset)
            sampleResults.append(.init(
                id: item.id, text: item.text, ipa: item.ipa, audioFile: fileName,
                synthMs: synthMs, audioMs: audioMs, rtfx: rtfx, wer: wer, cer: cer,
                peak: signal.peak, rms: signal.rms, clippingRatio: signal.clippingRatio,
                dcOffset: signal.dcOffset))
        }

        let meanWER = options.includeASR ? ErrorRateMeasurement(edits: wordEdits, referenceUnits: referenceWords).rate : nil
        let meanCER = options.includeASR ? ErrorRateMeasurement(edits: characterEdits, referenceUnits: referenceCharacters).rate : nil
        let meanClipping = clipping.reduce(0, +) / Double(clipping.count)
        let meanDC = dcOffsets.reduce(0, +) / Double(dcOffsets.count)
        let aggregateRTFx = totalSynthMs > 0 ? totalAudioMs / totalSynthMs : 0
        let score = BenchmarkScoring.score(
            wer: meanWER, cer: meanCER, utmos: nil,
            clippingRatio: meanClipping, rtfx: aggregateRTFx)
        let gates = makeGates(wer: meanWER, cer: meanCER, clipping: meanClipping, dc: meanDC, rtfx: aggregateRTFx)

        let corpusData = try Data(contentsOf: options.corpusURL)
        let corpusHash = SHA256.hash(data: corpusData).map { String(format: "%02x", $0) }.joined()
        let git = gitSnapshot()
        let system = systemSnapshot()
        let backendRows = BackendCatalog.descriptors.map {
            BenchmarkBackendResult(
                backend: $0.id,
                available: $0.id == options.backendID,
                note: $0.id == options.backendID ? "measured in this run" : "not measured in this run")
        }
        return BenchmarkReport(
            schemaVersion: 1,
            generatedAt: ISO8601DateFormatter().string(from: Date()),
            profile: options.profile,
            benchmarkVersion: 1,
            git: git,
            system: system,
            corpus: .init(path: relativePath(options.corpusURL), sha256: corpusHash, samples: items.count),
            aggregate: .init(
                backend: options.backendID, score: score, wer: meanWER, cer: meanCER,
                utmos: nil, rtfx: aggregateRTFx, clippingRatio: meanClipping, dcOffset: meanDC),
            gates: gates,
            backends: backendRows,
            samples: sampleResults)
    }

    private static func makeASR() async throws -> AsrManager {
        let models = try await AsrModels.downloadAndLoad()
        let manager = AsrManager()
        try await manager.loadModels(models)
        return manager
    }

    private static func makeGates(wer: Double?, cer: Double?, clipping: Double, dc: Double, rtfx: Double) -> BenchmarkGates {
        var failures: [String] = []
        if let wer, wer > 0.08 { failures.append(String(format: "WER %.2f%% > 8%%", wer * 100)) }
        if let cer, cer > 0.04 { failures.append(String(format: "CER %.2f%% > 4%%", cer * 100)) }
        if clipping > 0.001 { failures.append(String(format: "clipping %.3f%% > 0.1%%", clipping * 100)) }
        if abs(dc) > 0.05 { failures.append(String(format: "|DC offset| %.4f > 0.05", abs(dc))) }
        if rtfx < 1 { failures.append(String(format: "RTFx %.2f < 1", rtfx)) }
        return .init(passed: failures.isEmpty, failures: failures)
    }

    private static func gitSnapshot() -> BenchmarkGit {
        let env = ProcessInfo.processInfo.environment
        let tree = env["BENCHMARK_TREE"] ?? shell(["git", "write-tree"]) ?? "unknown"
        let branch = env["BENCHMARK_BRANCH"] ?? shell(["git", "branch", "--show-current"]) ?? "unknown"
        let commit = env["BENCHMARK_PRECOMMIT"] == "1" ? nil : (env["BENCHMARK_COMMIT"] ?? shell(["git", "rev-parse", "HEAD"]))
        return .init(tree: tree, branch: branch, commit: commit)
    }

    private static func systemSnapshot() -> BenchmarkSystem {
        let hardware = shell(["sysctl", "-n", "hw.model"]) ?? "unknown"
        #if arch(arm64)
        let arch = "arm64"
        #elseif arch(x86_64)
        let arch = "x86_64"
        #else
        let arch = "unknown"
        #endif
        return .init(hardware: hardware, os: ProcessInfo.processInfo.operatingSystemVersionString, arch: arch)
    }

    private static func shell(_ command: [String]) -> String? {
        guard !command.isEmpty else { return nil }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = command
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run(); process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch { return nil }
    }

    private static func relativePath(_ url: URL) -> String {
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).standardizedFileURL.path
        let path = url.standardizedFileURL.path
        return path.hasPrefix(cwd + "/") ? String(path.dropFirst(cwd.count + 1)) : path
    }
}

private extension Duration {
    var seconds: Double {
        let components = self.components
        return Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
}
