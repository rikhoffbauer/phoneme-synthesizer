import { describe, expect, test } from "bun:test";
import { historyEntryFromMarkdown } from "./history";
import { renderBenchmarkMarkdown } from "./benchmark-report";

const base = {
  schema_version: 1,
  generated_at: "2026-09-06T13:00:00Z",
  profile: "commit",
  benchmark_version: 1,
  git: { tree: "tree1", branch: "main", commit: null },
  system: { hardware: "Apple M4", os: "macOS 26.6", arch: "arm64" },
  corpus: { path: "commit.jsonl", sha256: "hash", samples: 3 },
  aggregate: { backend: "kokoro-ane", score: 99, wer: 0.01, cer: 0.002, utmos: null, rtfx: 30, clipping_ratio: 0, dc_offset: 0 },
  gates: { passed: true, failures: [] as string[] }, backends: [], samples: [],
};

describe("benchmark history", () => {
  test("uses commit metadata while preserving benchmark metrics", () => {
    const entry = historyEntryFromMarkdown(renderBenchmarkMarkdown(base), {
      sha: "1234567890abcdef", date: "2026-09-06T13:01:00Z", subject: "feat: baseline",
    });
    expect(entry.commit).toBe("1234567890abcdef");
    expect(entry.score).toBe(99);
    expect(entry.backend).toBe("kokoro-ane");
  });
});
