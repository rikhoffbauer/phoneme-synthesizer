import { parse, stringify } from "yaml";
import type { BenchmarkReport } from "./benchmark-report";
import { benchmarkScore } from "./benchmark-score";

export type UTMOSBatch = Record<string, { mean: number | null; samples: Array<{ file: string; utmos: number }> }>;

export type FullBackendResult = {
  backend: string;
  score: number;
  wer: number | null;
  cer: number | null;
  utmos: number | null;
  rtfx: number;
  clipping_ratio: number;
  gates_passed: boolean;
  gate_failures: string[];
  source_tree: string;
  measured_at: string;
};

export type FullComparison = {
  schema_version: 1;
  generated_at: string;
  benchmark_version: number;
  utmos_revision: string;
  git: BenchmarkReport["git"];
  system: BenchmarkReport["system"];
  corpus: BenchmarkReport["corpus"];
  source_trees: string[];
  mixed_source_trees: boolean;
  backends: FullBackendResult[];
};

export function buildFullComparison(
  reports: BenchmarkReport[],
  mos: UTMOSBatch,
  utmosRevision: string,
): FullComparison {
  if (reports.length === 0) throw new Error("full comparison requires benchmark reports");
  const first = reports[0];
  for (const report of reports.slice(1)) {
    if (report.corpus.sha256 !== first.corpus.sha256 || report.corpus.samples !== first.corpus.samples) {
      throw new Error("full comparison requires the same corpus for every backend");
    }
  }
  const backends = reports.map(report => {
    const a = report.aggregate;
    const utmos = mos[a.backend]?.mean ?? null;
    return {
      backend: a.backend,
      score: benchmarkScore(a.wer, a.cer, utmos, a.clipping_ratio, a.rtfx),
      wer: a.wer, cer: a.cer, utmos, rtfx: a.rtfx,
      clipping_ratio: a.clipping_ratio,
      gates_passed: report.gates.passed,
      gate_failures: report.gates.failures,
      source_tree: report.git.tree,
      measured_at: report.generated_at,
    } satisfies FullBackendResult;
  }).sort((a, b) => b.score - a.score);
  const sourceTrees = [...new Set(reports.map(report => report.git.tree))].sort();
  return {
    schema_version: 1,
    generated_at: new Date().toISOString(),
    benchmark_version: first.benchmark_version,
    utmos_revision: utmosRevision,
    git: first.git, system: first.system, corpus: first.corpus,
    source_trees: sourceTrees, mixed_source_trees: sourceTrees.length > 1, backends,
  };
}


const frontmatterPattern = /^---\n([\s\S]*?)\n---(?:\n|$)/;

export function parseFullComparisonMarkdown(markdown: string): FullComparison {
  const match = markdown.match(frontmatterPattern);
  if (!match) throw new Error("FULL_BENCHMARK_RESULTS.md has no YAML frontmatter");
  const value = parse(match[1]);
  if (!value || typeof value !== "object" || value.schema_version !== 1) {
    throw new Error("Unsupported or missing full comparison schema_version");
  }
  return value as FullComparison;
}

function pct(value: number | null): string {
  return value == null ? "—" : `${(value * 100).toFixed(2)}%`;
}

function num(value: number | null, digits = 3): string {
  return value == null ? "—" : value.toFixed(digits);
}

export function renderFullComparisonMarkdown(report: FullComparison): string {
  const yaml = stringify(report, { lineWidth: 0 }).trimEnd();
  const rows = report.backends.map(b =>
    `| \`${b.backend}\` | ${b.score.toFixed(2)} | ${pct(b.wer)} | ${pct(b.cer)} | ${num(b.utmos)} | ${b.rtfx.toFixed(2)}× | ${b.gates_passed ? "pass" : "fail"} | \`${b.source_tree.slice(0, 8)}\` |`
  );
  const table = [
    "| Backend | Score | WER | CER | UTMOS | RTFx | Gates | Tree |",
    "|---|---:|---:|---:|---:|---:|:---:|---|",
    ...rows,
  ].join("\n");
  const provenance = report.mixed_source_trees
    ? `\n\n> Provenance: this comparison reuses measurements from ${report.source_trees.length} source trees. Each backend row records its exact measurement tree in YAML frontmatter.`
    : `\n\nProvenance: all backend measurements came from source tree \`${report.source_trees[0]}\`.`;
  return `---\n${yaml}\n---\n\n# Full Backend Comparison\n\n${table}${provenance}\n\n` +
    `UTMOSv2 revision: \`${report.utmos_revision}\` · corpus: \`${report.corpus.path}\` (${report.corpus.samples} samples)\n`;
}
