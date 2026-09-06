import { execFileSync } from "node:child_process";
import { parseBenchmarkMarkdown } from "./benchmark-report";

export type GitCommitMeta = { sha: string; date: string; subject: string };
export type HistoryEntry = {
  commit: string; date: string; subject: string; tree: string; hardware: string;
  backend: string; score: number; wer: number | null; cer: number | null;
  utmos: number | null; rtfx: number; passed: boolean;
};

export function historyEntryFromMarkdown(markdown: string, meta: GitCommitMeta): HistoryEntry {
  const report = parseBenchmarkMarkdown(markdown);
  return {
    commit: meta.sha,
    date: meta.date,
    subject: meta.subject,
    tree: report.git.tree,
    hardware: report.system.hardware,
    backend: report.aggregate.backend,
    score: report.aggregate.score,
    wer: report.aggregate.wer,
    cer: report.aggregate.cer,
    utmos: report.aggregate.utmos,
    rtfx: report.aggregate.rtfx,
    passed: report.gates.passed,
  };
}

export function collectBenchmarkHistory(repoRoot = process.cwd()): HistoryEntry[] {
  let log = "";
  try {
    log = execFileSync("git", ["log", "--format=%H%x09%cI%x09%s", "--", "BENCHMARK_RESULTS.md"], {
      cwd: repoRoot, encoding: "utf8", stderr: "ignore",
    }).trim();
  } catch {
    return [];
  }
  if (!log) return [];
  const entries: HistoryEntry[] = [];
  for (const line of log.split("\n")) {
    const [sha, date, ...subjectParts] = line.split("\t");
    const subject = subjectParts.join("\t");
    const markdown = execFileSync("git", ["show", `${sha}:BENCHMARK_RESULTS.md`], {
      cwd: repoRoot, encoding: "utf8", maxBuffer: 10 * 1024 * 1024,
    });
    entries.push(historyEntryFromMarkdown(markdown, { sha, date, subject }));
  }
  return entries.reverse();
}
