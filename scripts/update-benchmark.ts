import { execFileSync, spawnSync } from "node:child_process";
import { copyFileSync, existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { tmpdir } from "node:os";
import { parseBenchmarkMarkdown, renderBenchmarkMarkdown, type BenchmarkReport } from "./benchmark-report";
import { benchmarkInvocation } from "./benchmark-command";
import { benchmarkScore } from "./benchmark-score";
import { buildFullComparison, renderFullComparisonMarkdown, type UTMOSBatch } from "./full-comparison";
import { utmosInvocation } from "./utmos-command";

const root = resolve(import.meta.dir, "..");
const profile = process.argv[2] ?? "commit";
if (!new Set(["commit", "full"]).has(profile)) throw new Error(`Unknown benchmark profile: ${profile}`);

function git(args: string[], env: Record<string, string> = {}): string | null {
  try { return execFileSync("git", args, { cwd: root, encoding: "utf8", env: { ...process.env, ...env } }).trim() || null; }
  catch { return null; }
}
function benchmarkSourceTree(): string {
  const indexPath = git(["rev-parse", "--git-path", "index"]);
  if (!indexPath) return git(["write-tree"]) ?? "working-tree-unavailable";
  const dir = mkdtempSync(join(tmpdir(), "phoneme-bench-index-"));
  const tempIndex = join(dir, "index");
  try {
    const absoluteIndex = resolve(root, indexPath);
    if (existsSync(absoluteIndex)) copyFileSync(absoluteIndex, tempIndex);
    const env = { GIT_INDEX_FILE: tempIndex };
    git(["update-index", "--force-remove", "BENCHMARK_RESULTS.md"], env);
    return git(["write-tree"], env) ?? "working-tree-unavailable";
  } finally { rmSync(dir, { recursive: true, force: true }); }
}
function run(command: string, args: string[], env: Record<string, string> = {}) {
  const proc = spawnSync(command, args, { cwd: root, stdio: "inherit", env: { ...process.env, ...env } });
  if (proc.status !== 0) throw new Error(`${command} exited ${proc.status ?? "without status"}`);
}
const tree = benchmarkSourceTree();
const branch = git(["branch", "--show-current"]) ?? "detached";
const benchRoot = resolve(root, ".benchmarks");
mkdirSync(benchRoot, { recursive: true });
const commonEnv = {
  BENCHMARK_TREE: tree,
  BENCHMARK_BRANCH: branch,
  BENCHMARK_PRECOMMIT: process.env.GITHUB_SHA ? "0" : "1",
  ...(process.env.GITHUB_SHA ? { BENCHMARK_COMMIT: process.env.GITHUB_SHA } : {}),
};

function runCLI(args: string[], env: Record<string, string> = commonEnv) {
  const invocation = benchmarkInvocation(process.env.PHONEME_SYNTH_BIN, args);
  run(invocation.command, invocation.args, env);
}

function runBackend(backend: string, output: string, audioDir: string, extra: string[] = []) {
  mkdirSync(audioDir, { recursive: true });
  runCLI([
    "benchmark", "--profile", profile, "--backend", backend,
    "--corpus", "Benchmarks/corpus/commit.jsonl",
    "--output-json", output, "--audio-dir", audioDir, ...extra,
  ]);
  return JSON.parse(readFileSync(output, "utf8")) as BenchmarkReport;
}

const output = resolve(benchRoot, "latest.json");
const audioDir = resolve(benchRoot, "audio");
let report = runBackend("kokoro-ane", output, audioDir);

if (profile === "full") {
  const refDir = resolve(benchRoot, "reference");
  mkdirSync(refDir, { recursive: true });
  const rawRef = resolve(refDir, "raw.wav");
  const fixedRef = resolve(refDir, "reference-2.875s.wav");
  const promptIPA = "ɐ kˈɑːm vˈɔɪs spˈiːks klˈɪɹli ænd stˈɛdili";
  runCLI(["synth", "--backend", "kokoro-ane", "--ipa", promptIPA, "--output", rawRef], {});
  run("python3", ["scripts/trim-wav.py", rawRef, fixedRef, "--seconds", "2.875"]);

  const candidates = [
    { id: "kokoro-ane", report, dir: audioDir },
    { id: "inflect-v2", report: runBackend("inflect-v2", resolve(benchRoot, "inflect-v2.json"), resolve(benchRoot, "audio-inflect")), dir: resolve(benchRoot, "audio-inflect") },
    { id: "styletts2", report: runBackend("styletts2", resolve(benchRoot, "styletts2.json"), resolve(benchRoot, "audio-styletts2"), ["--reference", fixedRef]), dir: resolve(benchRoot, "audio-styletts2") },
    { id: "luxtts", report: runBackend("luxtts", resolve(benchRoot, "luxtts.json"), resolve(benchRoot, "audio-luxtts"), ["--reference", fixedRef, "--prompt-phonemes", promptIPA]), dir: resolve(benchRoot, "audio-luxtts") },
    { id: "toucan-articulatory", report: runBackend("toucan-articulatory", resolve(benchRoot, "toucan-articulatory.json"), resolve(benchRoot, "audio-toucan")), dir: resolve(benchRoot, "audio-toucan") },
  ];

  const utmosRevision = "cc2700db57bb83ee13dc31ebe1b868c254e15d09";
  const mosFile = resolve(benchRoot, "utmos-all.json");
  const invocation = utmosInvocation(utmosRevision, mosFile, candidates.map(c => [c.id, c.dir] as const));
  run(invocation.command, invocation.args);
  const mos = JSON.parse(readFileSync(mosFile, "utf8")) as UTMOSBatch;
  for (const candidate of candidates) {
    const batch = mos[candidate.id];
    if (!batch) throw new Error(`UTMOS result missing backend ${candidate.id}`);
    const byFile = new Map(batch.samples.map(x => [x.file, x.utmos]));
    for (const sample of candidate.report.samples as any[]) sample.utmos = sample.audio_file ? (byFile.get(sample.audio_file) ?? null) : null;
    candidate.report.aggregate.utmos = batch.mean;
    const a = candidate.report.aggregate;
    a.score = benchmarkScore(a.wer, a.cer, a.utmos, a.clipping_ratio, a.rtfx);
  }
  report = candidates[0].report;
  writeFileSync(output, JSON.stringify(report, null, 2) + "\n");
  const comparison = buildFullComparison(candidates.map(c => c.report), mos, utmosRevision);
  writeFileSync(resolve(benchRoot, "full-latest.json"), JSON.stringify(comparison, null, 2) + "\n");
  writeFileSync(resolve(root, "FULL_BENCHMARK_RESULTS.md"), renderFullComparisonMarkdown(comparison));
  console.log(`Updated FULL_BENCHMARK_RESULTS.md (${comparison.backends.length} backends)`);
} else {
  const markdown = renderBenchmarkMarkdown(report);
  writeFileSync(resolve(root, "BENCHMARK_RESULTS.md"), markdown);
  parseBenchmarkMarkdown(markdown);
  console.log(`Updated BENCHMARK_RESULTS.md (score ${report.aggregate.score.toFixed(2)}, tree ${report.git.tree})`);
}
