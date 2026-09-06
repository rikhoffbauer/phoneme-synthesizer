import { describe, expect, test } from "bun:test";
import { assertBenchmarkValid, parseBenchmarkMarkdown, renderBenchmarkMarkdown } from "./benchmark-report";

const report = {
  schema_version: 1,
  generated_at: "2026-09-06T13:00:00Z",
  profile: "commit",
  benchmark_version: 1,
  git: { tree: "abc123", branch: "main", commit: null },
  system: { hardware: "Apple M4", os: "macOS 26.6", arch: "arm64" },
  corpus: { path: "Benchmarks/corpus/commit.jsonl", sha256: "deadbeef", samples: 2 },
  aggregate: {
    backend: "kokoro-ane", score: 98.2, wer: 0.01, cer: 0.002,
    utmos: null, rtfx: 20.5, clipping_ratio: 0, dc_offset: 0.0001,
  },
  gates: { passed: true, failures: [] as string[] },
  backends: [],
  samples: [],
};

describe("benchmark Markdown", () => {
  test("round-trips the machine-readable YAML frontmatter", () => {
    const markdown = renderBenchmarkMarkdown(report);
    expect(markdown.startsWith("---\n")).toBe(true);
    const parsed = parseBenchmarkMarkdown(markdown);
    expect(parsed.schema_version).toBe(1);
    expect(parsed.git.tree).toBe("abc123");
    expect(parsed.aggregate.utmos).toBeNull();
  });

  test("renders a human-readable metric table from the same report", () => {
    const markdown = renderBenchmarkMarkdown(report);
    expect(markdown).toContain("| Score | 98.20 |");
    expect(markdown).toContain("| WER | 1.00% |");
    expect(markdown).toContain("not measured");
  });

  test("rejects reports whose regression gates failed", () => {
    const failed = { ...report, gates: { passed: false, failures: ["WER 12% > 8%"] } };
    expect(() => assertBenchmarkValid(failed)).toThrow("Benchmark gates failed: WER 12% > 8%");
  });
});
