import { execFileSync, spawnSync } from "node:child_process";
import { copyFileSync, existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { tmpdir } from "node:os";
import { parseBenchmarkMarkdown, renderBenchmarkMarkdown, type BenchmarkReport } from "./benchmark-report";

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
function score(wer: number | null, cer: number | null, utmos: number | null, clipping: number, rtfx: number) {
  let value = 100;
  if (wer != null) value -= Math.min(60, Math.max(0, wer) * 240);
  if (cer != null) value -= Math.min(25, Math.max(0, cer) * 250);
  value -= Math.min(10, Math.max(0, clipping) * 1000);
  if (utmos != null) value += Math.max(-5, Math.min(5, (utmos - 3.5) * 3.33));
  value += Math.min(2, Math.log2(Math.max(rtfx, 1)) * 0.4);
  return Math.min(100, Math.max(0, value));
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

function runBackend(backend: string, output: string, audioDir: string, extra: string[] = []) {
  mkdirSync(audioDir, { recursive: true });
  run("swift", [
    "run", "-c", "release", "phoneme-synth", "benchmark",
    "--profile", profile, "--backend", backend,
    "--corpus", "Benchmarks/corpus/commit.jsonl",
    "--output-json", output, "--audio-dir", audioDir, ...extra,
  ], commonEnv);
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
  run("swift", ["run", "-c", "release", "phoneme-synth", "synth", "--backend", "kokoro-ane", "--ipa", promptIPA, "--output", rawRef]);
  run("python3", ["scripts/trim-wav.py", rawRef, fixedRef, "--seconds", "2.875"]);

  const candidates = [
    { id: "kokoro-ane", report, dir: audioDir },
    { id: "inflect-v2", report: runBackend("inflect-v2", resolve(benchRoot, "inflect-v2.json"), resolve(benchRoot, "audio-inflect")), dir: resolve(benchRoot, "audio-inflect") },
    { id: "styletts2", report: runBackend("styletts2", resolve(benchRoot, "styletts2.json"), resolve(benchRoot, "audio-styletts2"), ["--reference", fixedRef]), dir: resolve(benchRoot, "audio-styletts2") },
    { id: "luxtts", report: runBackend("luxtts", resolve(benchRoot, "luxtts.json"), resolve(benchRoot, "audio-luxtts"), ["--reference", fixedRef, "--prompt-phonemes", promptIPA]), dir: resolve(benchRoot, "audio-luxtts") },
  ];

  const utmosRevision = "cc2700db57bb83ee13dc31ebe1b868c254e15d09";
  for (const candidate of candidates) {
    const mosFile = resolve(benchRoot, `utmos-${candidate.id}.json`);
    run("uv", [
      "run", "--python", "3.11",
      "--with", `utmosv2 @ git+https://github.com/sarulab-speech/UTMOSv2.git@${utmosRevision}`,
      "python", "scripts/score-utmos.py", candidate.dir, mosFile,
    ]);
    const rows = JSON.parse(readFileSync(mosFile, "utf8")) as { file: string; utmos: number }[];
    const byFile = new Map(rows.map(x => [x.file, x.utmos]));
    for (const sample of candidate.report.samples as any[]) sample.utmos = sample.audio_file ? (byFile.get(sample.audio_file) ?? null) : null;
    const values = rows.map(x => x.utmos);
    candidate.report.aggregate.utmos = values.length ? values.reduce((a,b)=>a+b,0) / values.length : null;
    candidate.report.aggregate.score = score(candidate.report.aggregate.wer, candidate.report.aggregate.cer, candidate.report.aggregate.utmos, candidate.report.aggregate.clipping_ratio, candidate.report.aggregate.rtfx);
  }
  report = candidates[0].report;
  (report as any).backends = candidates.map(c => ({
    backend: c.id, available: true, note: "full-profile measured",
    score: c.report.aggregate.score, wer: c.report.aggregate.wer, cer: c.report.aggregate.cer,
    utmos: c.report.aggregate.utmos, rtfx: c.report.aggregate.rtfx,
    clipping_ratio: c.report.aggregate.clipping_ratio,
  }));
  writeFileSync(output, JSON.stringify(report, null, 2) + "\n");
}

const markdown = renderBenchmarkMarkdown(report);
writeFileSync(resolve(root, "BENCHMARK_RESULTS.md"), markdown);
parseBenchmarkMarkdown(markdown);
console.log(`Updated BENCHMARK_RESULTS.md (score ${report.aggregate.score.toFixed(2)}, tree ${report.git.tree})`);
