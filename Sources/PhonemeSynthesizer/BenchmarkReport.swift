import Foundation

public struct BenchmarkAggregate: Codable, Sendable, Equatable {
    public let backend: String
    public let score: Double
    public let wer: Double?
    public let cer: Double?
    public let utmos: Double?
    public let rtfx: Double
    public let clippingRatio: Double
    public let dcOffset: Double

    public init(backend: String, score: Double, wer: Double?, cer: Double?, utmos: Double?, rtfx: Double, clippingRatio: Double, dcOffset: Double) {
        self.backend = backend; self.score = score; self.wer = wer; self.cer = cer
        self.utmos = utmos; self.rtfx = rtfx; self.clippingRatio = clippingRatio; self.dcOffset = dcOffset
    }

    private enum CodingKeys: String, CodingKey { case backend, score, wer, cer, utmos, rtfx, clippingRatio, dcOffset }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(backend, forKey: .backend); try c.encode(score, forKey: .score)
        if let wer { try c.encode(wer, forKey: .wer) } else { try c.encodeNil(forKey: .wer) }
        if let cer { try c.encode(cer, forKey: .cer) } else { try c.encodeNil(forKey: .cer) }
        if let utmos { try c.encode(utmos, forKey: .utmos) } else { try c.encodeNil(forKey: .utmos) }
        try c.encode(rtfx, forKey: .rtfx); try c.encode(clippingRatio, forKey: .clippingRatio); try c.encode(dcOffset, forKey: .dcOffset)
    }
}

public struct BenchmarkGit: Codable, Sendable, Equatable {
    public let tree: String; public let branch: String; public let commit: String?
    public init(tree: String, branch: String, commit: String?) { self.tree = tree; self.branch = branch; self.commit = commit }

    private enum CodingKeys: String, CodingKey { case tree, branch, commit }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(tree, forKey: .tree); try c.encode(branch, forKey: .branch)
        if let commit { try c.encode(commit, forKey: .commit) } else { try c.encodeNil(forKey: .commit) }
    }
}
public struct BenchmarkSystem: Codable, Sendable, Equatable {
    public let hardware: String; public let os: String; public let arch: String
    public init(hardware: String, os: String, arch: String) { self.hardware = hardware; self.os = os; self.arch = arch }
}
public struct BenchmarkCorpus: Codable, Sendable, Equatable {
    public let path: String; public let sha256: String; public let samples: Int
    public init(path: String, sha256: String, samples: Int) { self.path = path; self.sha256 = sha256; self.samples = samples }
}
public struct BenchmarkGates: Codable, Sendable, Equatable {
    public let passed: Bool; public let failures: [String]
    public init(passed: Bool, failures: [String]) { self.passed = passed; self.failures = failures }
}
public struct BenchmarkBackendResult: Codable, Sendable, Equatable {
    public let backend: String; public let available: Bool; public let note: String?
    public init(backend: String, available: Bool, note: String? = nil) { self.backend = backend; self.available = available; self.note = note }
}
public struct BenchmarkSampleResult: Codable, Sendable, Equatable {
    public let id: String; public let text: String; public let ipa: String
    public let audioFile: String?; public let synthMs: Double; public let audioMs: Double; public let rtfx: Double
    public let wer: Double?; public let cer: Double?; public let peak: Double; public let rms: Double
    public let clippingRatio: Double; public let dcOffset: Double

    private enum CodingKeys: String, CodingKey { case id, text, ipa, audioFile, synthMs, audioMs, rtfx, wer, cer, peak, rms, clippingRatio, dcOffset }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id); try c.encode(text, forKey: .text); try c.encode(ipa, forKey: .ipa)
        if let audioFile { try c.encode(audioFile, forKey: .audioFile) } else { try c.encodeNil(forKey: .audioFile) }
        try c.encode(synthMs, forKey: .synthMs); try c.encode(audioMs, forKey: .audioMs); try c.encode(rtfx, forKey: .rtfx)
        if let wer { try c.encode(wer, forKey: .wer) } else { try c.encodeNil(forKey: .wer) }
        if let cer { try c.encode(cer, forKey: .cer) } else { try c.encodeNil(forKey: .cer) }
        try c.encode(peak, forKey: .peak); try c.encode(rms, forKey: .rms)
        try c.encode(clippingRatio, forKey: .clippingRatio); try c.encode(dcOffset, forKey: .dcOffset)
    }
}
public struct BenchmarkReport: Codable, Sendable, Equatable {
    public let schemaVersion: Int; public let generatedAt: String; public let profile: String; public let benchmarkVersion: Int
    public let git: BenchmarkGit; public let system: BenchmarkSystem; public let corpus: BenchmarkCorpus
    public let aggregate: BenchmarkAggregate; public let gates: BenchmarkGates
    public let backends: [BenchmarkBackendResult]; public let samples: [BenchmarkSampleResult]

    public init(schemaVersion: Int, generatedAt: String, profile: String, benchmarkVersion: Int, git: BenchmarkGit, system: BenchmarkSystem, corpus: BenchmarkCorpus, aggregate: BenchmarkAggregate, gates: BenchmarkGates, backends: [BenchmarkBackendResult], samples: [BenchmarkSampleResult]) {
        self.schemaVersion = schemaVersion; self.generatedAt = generatedAt; self.profile = profile; self.benchmarkVersion = benchmarkVersion
        self.git = git; self.system = system; self.corpus = corpus; self.aggregate = aggregate; self.gates = gates; self.backends = backends; self.samples = samples
    }
}

public enum BenchmarkScoring {
    public static func score(wer: Double?, cer: Double?, utmos: Double?, clippingRatio: Double, rtfx: Double) -> Double {
        var score = 100.0
        if let wer { score -= min(60, max(0, wer) * 240) }
        if let cer { score -= min(25, max(0, cer) * 250) }
        score -= min(10, max(0, clippingRatio) * 1_000)
        if let utmos { score += max(-5, min(5, (utmos - 3.5) * 3.33)) }
        score += min(2, log2(max(rtfx, 1)) * 0.4)
        return min(100, max(0, score))
    }
}
