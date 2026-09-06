import Foundation
import FluidAudio

public enum ToucanIPAAdapter {
    public static func canonicalize(_ ipa: String) throws -> String {
        let value = ipa
            .replacingOccurrences(of: "ə˞", with: "əɹ")
            .replacingOccurrences(of: "ɜ˞", with: "ɜɹ")
            .replacingOccurrences(of: "ɚ", with: "əɹ")
            .replacingOccurrences(of: "ɝ", with: "ɜɹ")
            .replacingOccurrences(of: "ˌ", with: "ˈ")
            .replacingOccurrences(of: "ʲ", with: "̧")
            .replacingOccurrences(of: "ˤ", with: "ˁ")
            .replacingOccurrences(of: "ɥ", with: "jʷ")
            .replacingOccurrences(of: "ⱱ", with: "ѵ")

        if value.unicodeScalars.contains(where: { $0.value == 0x02DE }) {
            throw BackendError.unsupportedSymbols(
                backend: "toucan-articulatory", symbols: ["˞"]
            )
        }
        return value
    }
}

public struct ToucanWorkerConfiguration: Sendable, Equatable {
    public let pythonExecutable: URL
    public let workerScript: URL
    public let toucanRepository: URL

    public init(pythonExecutable: URL, workerScript: URL, toucanRepository: URL) {
        self.pythonExecutable = pythonExecutable
        self.workerScript = workerScript
        self.toucanRepository = toucanRepository
    }

    public static func installedDefault() throws -> ToucanWorkerConfiguration {
        let env = ProcessInfo.processInfo.environment
        let root = URL(fileURLWithPath: env["PHONEME_SYNTH_TOUCAN_ROOT"] ??
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".cache/phoneme-synthesizer/toucan").path)
        guard let worker = Bundle.module.url(forResource: "toucan_worker", withExtension: "py") else {
            throw BackendError.unsupportedOption("Bundled Toucan worker resource is missing.")
        }
        return ToucanWorkerConfiguration(
            pythonExecutable: URL(fileURLWithPath: env["PHONEME_SYNTH_TOUCAN_PYTHON"] ??
                root.appendingPathComponent(".venv/bin/python").path),
            workerScript: worker,
            toucanRepository: URL(fileURLWithPath: env["PHONEME_SYNTH_TOUCAN_REPO"] ??
                root.appendingPathComponent("IMS-Toucan").path)
        )
    }
}

private struct ToucanWorkerRequest: Encodable {
    let id: String
    let ipa: String
    let output: String
    let speed: Float
    let seed: UInt64
}

private struct ToucanWorkerResponse: Decodable {
    let id: String?
    let ready: Bool?
    let ok: Bool?
    let sampleRate: Int?
    let synthesisSeconds: Double?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case id, ready, ok, error
        case sampleRate = "sample_rate"
        case synthesisSeconds = "synthesis_seconds"
    }
}

private actor ToucanWorkerClient {
    private let configuration: ToucanWorkerConfiguration
    private var process: Process?
    private var input: FileHandle?
    private var output: FileHandle?
    private var readBuffer = Data()

    init(configuration: ToucanWorkerConfiguration) {
        self.configuration = configuration
    }

    deinit {
        if process?.isRunning == true { process?.terminate() }
        try? input?.close()
        try? output?.close()
    }

    func synthesize(ipa: String, options: SynthesisOptions) throws -> SynthesizedAudio {
        try ensureStarted()
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("toucan-\(UUID().uuidString).wav")
        defer { try? FileManager.default.removeItem(at: outputURL) }
        let request = ToucanWorkerRequest(
            id: UUID().uuidString, ipa: ipa, output: outputURL.path,
            speed: options.speed, seed: options.seed
        )
        var payload = try JSONEncoder().encode(request)
        payload.append(0x0A)
        try input?.write(contentsOf: payload)
        let response = try readResponse()
        guard response.ok == true else {
            throw BackendError.unsupportedOption(
                "Toucan worker failed: \(response.error ?? "unknown error")"
            )
        }
        let sampleRate = response.sampleRate ?? 24_000
        let samples = try AudioConverter(sampleRate: Double(sampleRate))
            .resampleAudioFile(outputURL)
        return SynthesizedAudio(
            samples: samples, sampleRate: sampleRate, backend: "toucan-articulatory",
            metadata: ["model_seconds": response.synthesisSeconds ?? 0]
        )
    }

    private func ensureStarted() throws {
        if process?.isRunning == true { return }
        let fm = FileManager.default
        guard fm.isExecutableFile(atPath: configuration.pythonExecutable.path),
              fm.fileExists(atPath: configuration.workerScript.path),
              fm.fileExists(atPath: configuration.toucanRepository.path) else {
            throw BackendError.unsupportedOption(
                "Toucan is not installed. Run `bun run toucan:setup`, then retry."
            )
        }
        let process = Process()
        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        process.executableURL = configuration.pythonExecutable
        process.arguments = [configuration.workerScript.path]
        process.currentDirectoryURL = configuration.toucanRepository
        var environment = ProcessInfo.processInfo.environment
        environment["PHONEME_SYNTH_TOUCAN_REPO"] = configuration.toucanRepository.path
        environment["PYTHONUNBUFFERED"] = "1"
        process.environment = environment
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = FileHandle.standardError
        try process.run()
        self.process = process
        self.input = stdinPipe.fileHandleForWriting
        self.output = stdoutPipe.fileHandleForReading
        readBuffer.removeAll(keepingCapacity: true)
        let response = try readResponse()
        guard response.ready == true else {
            process.terminate()
            throw BackendError.unsupportedOption(
                "Toucan worker did not become ready: \(response.error ?? "unknown error")"
            )
        }
    }

    private func readResponse() throws -> ToucanWorkerResponse {
        while true {
            if let newline = readBuffer.firstIndex(of: 0x0A) {
                let line = readBuffer[..<newline]
                readBuffer.removeSubrange(...newline)
                return try JSONDecoder().decode(ToucanWorkerResponse.self, from: Data(line))
            }
            guard let output else {
                throw BackendError.unsupportedOption("Toucan worker has no output pipe.")
            }
            let chunk = output.availableData
            guard !chunk.isEmpty else {
                throw BackendError.unsupportedOption("Toucan worker closed its output unexpectedly.")
            }
            readBuffer.append(chunk)
        }
    }
}

public actor ToucanArticulatoryBackend: PhonemeSynthesisBackend {
    public nonisolated let descriptor = BackendCatalog.descriptor(id: "toucan-articulatory")!
    private let client: ToucanWorkerClient

    public init(configuration: ToucanWorkerConfiguration) {
        client = ToucanWorkerClient(configuration: configuration)
    }

    public func synthesize(_ input: IPAInput, options: SynthesisOptions) async throws -> SynthesizedAudio {
        let ipa = try ToucanIPAAdapter.canonicalize(input.value)
        return try await client.synthesize(ipa: ipa, options: options)
    }
}
