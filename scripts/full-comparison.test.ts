import { describe, expect, test } from "bun:test";
import { buildFullComparison, parseFullComparisonMarkdown, renderFullComparisonMarkdown } from "./full-comparison";

const base = (backend: string, score: number, wer: number, cer: number, rtfx: number, tree = "tree") => ({
  schema_version: 1, generated_at: "2026-09-06T00:00:00Z", profile: "full", benchmark_version: 1,
  git: { tree, branch: "main", commit: "commit" },
  system: { hardware: "Mac16,12", os: "macOS", arch: "arm64" },
  corpus: { path: "Benchmarks/corpus/commit.jsonl", sha256: "hash", samples: 12 },
  aggregate: { backend, score, wer, cer, utmos: null, rtfx, clipping_ratio: 0, dc_offset: 0 },
  gates: { passed: wer <= 0.08 && cer <= 0.04 && rtfx >= 1, failures: [] }, backends: [], samples: [],
});

describe("full benchmark comparison", () => {
  test("merges MOS values and ranks by recomputed score", () => {
    const report = buildFullComparison([base("kokoro-ane", 100, 0, 0, 3), base("toucan-articulatory", 20, .22, .10, .3)],
      { "kokoro-ane": { mean: 4.0, samples: [] }, "toucan-articulatory": { mean: 3.0, samples: [] } }, "utmos-rev");
    expect(report.backends[0].backend).toBe("kokoro-ane");
    expect(report.backends[0].utmos).toBe(4);
    expect(report.backends[1].backend).toBe("toucan-articulatory");
    expect(report.backends[0].source_tree).toBe("tree");
    expect(report.source_trees).toEqual(["tree"]);
    expect(report.mixed_source_trees).toBe(false);
    const markdown = renderFullComparisonMarkdown(report);
    expect(markdown).toContain("| `kokoro-ane` |");
    expect(parseFullComparisonMarkdown(markdown).backends[0].backend).toBe("kokoro-ane");
  });
  test("flags comparisons assembled from different source trees", () => {
    const report = buildFullComparison([
      base("kokoro-ane", 100, 0, 0, 3, "tree-a"),
      base("toucan-articulatory", 20, .22, .10, .3, "tree-b"),
    ], {}, "utmos-rev");
    expect(report.source_trees).toEqual(["tree-a", "tree-b"]);
    expect(report.mixed_source_trees).toBe(true);
  });

  test("rejects comparisons across different corpora", () => {
    const a = base("kokoro-ane", 100, 0, 0, 3);
    const b = base("toucan-articulatory", 20, .22, .10, .3);
    b.corpus.sha256 = "other-hash";
    expect(() => buildFullComparison([a, b], {}, "utmos-rev")).toThrow("same corpus");
  });

});
