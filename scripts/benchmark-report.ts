import { parse, stringify } from "yaml";

export type BenchmarkReport = {
  schema_version: number;
  generated_at: string;
  profile: string;
  benchmark_version: number;
  git: { tree: string; branch: string; commit: string | null };
  system: { hardware: string; os: string; arch: string };
  corpus: { path: string; sha256: string; samples: number };
  aggregate: {
    backend: string;
    score: number;
    wer: number | null;
    cer: number | null;
    utmos: number | null;
    rtfx: number;
    clipping_ratio: number;
    dc_offset: number;
  };
  gates: { passed: boolean; failures: string[] };
  backends: unknown[];
  samples: Array<{
    id?: string;
    text?: string;
    ipa?: string;
    audio_file?: string | null;
    synth_ms?: number;
    audio_ms?: number;
    rtfx?: number;
    wer?: number | null;
    cer?: number | null;
    peak?: number;
    rms?: number;
    clipping_ratio?: number;
    dc_offset?: number;
  }>;
};

const frontmatterPattern = /^---\n([\s\S]*?)\n---(?:\n|$)/;

export function parseBenchmarkMarkdown(markdown: string): BenchmarkReport {
  const match = markdown.match(frontmatterPattern);
  if (!match) throw new Error("BENCHMARK_RESULTS.md has no YAML frontmatter");
  const value = parse(match[1]);
  if (!value || typeof value !== "object" || value.schema_version !== 1) {
    throw new Error("Unsupported or missing benchmark schema_version");
  }
  return value as BenchmarkReport;
}

export function assertBenchmarkValid(report: BenchmarkReport): void {
  if (report.corpus.samples < 1) throw new Error("Benchmark corpus must contain samples");
  if (!Number.isFinite(report.aggregate.score)) throw new Error("Benchmark score is not finite");
  if (!report.gates.passed) {
    const detail = report.gates.failures.length ? report.gates.failures.join("; ") : "unspecified gate failure";
    throw new Error(`Benchmark gates failed: ${detail}`);
  }
}

function pct(value: number | null): string {
  return value == null ? "not measured" : `${(value * 100).toFixed(2)}%`;
}

function number(value: number | null, digits = 2): string {
  return value == null ? "not measured" : value.toFixed(digits);
}

export function renderBenchmarkMarkdown(report: BenchmarkReport): string {
  const yaml = stringify(report, { lineWidth: 0 }).trimEnd();
  const a = report.aggregate;
  const rows = [
    ["Score", a.score.toFixed(2)],
    ["Backend", `\`${a.backend}\``],
    ["WER", pct(a.wer)],
    ["CER", pct(a.cer)],
    ["UTMOS", number(a.utmos, 3)],
    ["RTFx", `${a.rtfx.toFixed(2)}×`],
    ["Clipping ratio", pct(a.clipping_ratio)],
    ["DC offset", a.dc_offset.toExponential(3)],
  ];
  const table = ["| Metric | Result |", "| --- | ---: |", ...rows.map(([k, v]) => `| ${k} | ${v} |`)].join("\n");
  const gate = report.gates.passed
    ? "All benchmark gates passed."
    : `Benchmark gates failed: ${report.gates.failures.join("; ")}`;
  return `---\n${yaml}\n---\n\n# Benchmark Results\n\n${table}\n\n${gate}\n\n` +
    `Profile: \`${report.profile}\` · corpus: \`${report.corpus.path}\` (${report.corpus.samples} samples) · tree: \`${report.git.tree}\`\n`;
}
