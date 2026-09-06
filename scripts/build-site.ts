import { execFileSync } from "node:child_process";
import { copyFileSync, cpSync, existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";
import { collectBenchmarkHistory, historyEntryFromMarkdown } from "./history";
import { parseBenchmarkMarkdown } from "./benchmark-report";
import { parseFullComparisonMarkdown } from "./full-comparison";

const root = resolve(import.meta.dir, "..");
const publicDir = resolve(root, "site/public");
const dataDir = resolve(publicDir, "data");
const audioTarget = resolve(publicDir, "audio");
mkdirSync(dataDir, { recursive: true });
mkdirSync(audioTarget, { recursive: true });

const latestJSON = resolve(root, ".benchmarks/latest.json");
const benchmarkMD = resolve(root, "BENCHMARK_RESULTS.md");
let current: any;
if (existsSync(benchmarkMD)) current = parseBenchmarkMarkdown(readFileSync(benchmarkMD, "utf8"));
else current = JSON.parse(readFileSync(latestJSON, "utf8"));
writeFileSync(resolve(dataDir, "current.json"), JSON.stringify(current, null, 2));

const fullMD = resolve(root, "FULL_BENCHMARK_RESULTS.md");
const full = existsSync(fullMD) ? parseFullComparisonMarkdown(readFileSync(fullMD, "utf8")) : null;
writeFileSync(resolve(dataDir, "full.json"), JSON.stringify(full, null, 2));

let history = collectBenchmarkHistory(root);
const sha = process.env.GITHUB_SHA ?? (() => {
  try { return execFileSync("git", ["rev-parse", "HEAD"], { cwd: root, encoding: "utf8" }).trim(); }
  catch { return "working-tree"; }
})();
const date = new Date().toISOString();
const subject = (() => {
  try { return execFileSync("git", ["log", "-1", "--format=%s"], { cwd: root, encoding: "utf8" }).trim(); }
  catch { return "working tree"; }
})();
const currentMarkdown = existsSync(benchmarkMD) ? readFileSync(benchmarkMD, "utf8") : null;
if (currentMarkdown) {
  const entry = historyEntryFromMarkdown(currentMarkdown, { sha, date, subject });
  history = history.filter((x) => x.commit !== sha);
  history.push({ ...entry, score: current.aggregate.score, wer: current.aggregate.wer, cer: current.aggregate.cer, utmos: current.aggregate.utmos, rtfx: current.aggregate.rtfx, passed: current.gates.passed });
}
writeFileSync(resolve(dataDir, "history.json"), JSON.stringify(history, null, 2));

if (existsSync(resolve(root, ".benchmarks/audio"))) cpSync(resolve(root, ".benchmarks/audio"), audioTarget, { recursive: true });
copyFileSync(resolve(root, "README.md"), resolve(publicDir, "README.md"));
mkdirSync(resolve(publicDir, "docs"), { recursive: true });
copyFileSync(resolve(root, "docs/PHONE_SYMBOL_SUPPORT.md"), resolve(publicDir, "docs/PHONE_SYMBOL_SUPPORT.md"));
copyFileSync(resolve(root, "docs/superpowers/specs/2026-09-06-phoneme-synthesizer-design.md"), resolve(publicDir, "DESIGN.md"));
console.log(`site data: ${history.length} historical entries, ${current.samples?.length ?? 0} current samples`);
