# Phoneme Synthesizer Design

## Goal
Build a local Apple-Silicon phoneme-to-waveform synthesizer whose quality can be improved objectively from commit to commit.

## Inputs and correctness
The primary API accepts already-phonemized IPA/espeak-style strings. Decorative `/.../` and `[...]` delimiters may be stripped, Unicode is normalized deterministically, and empty input is rejected. Backend-supported symbol validation must be explicit; unknown phones must never be silently discarded.

Each benchmark sample stores both the exact phoneme input and an orthographic reference used only for ASR round-trip scoring. Synthesis never reconstructs text from that reference.

## Backend architecture
A `PhonemeSynthesisBackend` protocol isolates rendering. Initial adapters:

1. Kokoro ANE: default, reference-free, 24 kHz.
2. LuxTTS: 48 kHz, prompt-audio + prompt-phoneme conditioned.
3. StyleTTS2: 24 kHz, reference-audio conditioned.
4. Inflect v2: 24 kHz experimental compact baseline.

The CLI exposes the default immediately and can enumerate backends. Reference-conditioned backends fail explicitly when required conditioning inputs are absent.

## Benchmark-first loop
The commit benchmark runs a small deterministic English IPA corpus through the selected default backend and records synthesis latency, generated duration, RTFx, clipping ratio, DC offset, peak, RMS, and ASR round-trip WER/CER when ASR scoring is enabled. Full benchmarks add larger corpora, candidate backends, and perceptual MOS metrics (UTMOSv2/other predictors) without changing the commit report schema.

`BENCHMARK_RESULTS.md` contains YAML frontmatter plus a human-readable Markdown summary. Its canonical data comes from `.benchmarks/latest.json`; a Bun renderer writes both representations from one report object.

## Commit identity
A pre-commit hook benchmarks the staged working tree before the commit exists. It copies the Git index to a temporary index, removes `BENCHMARK_RESULTS.md`, and runs `git write-tree` there. The stored tree is therefore a genuine Git tree containing every staged benchmark input but not the self-referential generated result file. The hook stages the regenerated Markdown automatically; git history supplies the eventual commit SHA.

## Benchmark schema
Frontmatter fields include:
- `schema_version`
- `generated_at`
- `profile`
- `benchmark_version`
- `git.tree`
- `git.branch`
- `system.hardware`, `system.os`, `system.arch`
- `corpus.path`, `corpus.sha256`, `corpus.samples`
- `aggregate.backend`, `aggregate.score`, `aggregate.wer`, `aggregate.cer`, `aggregate.utmos`, `aggregate.rtfx`, signal metrics
- `gates`
- per-backend/per-sample result summaries

Unknown/unrun metrics are `null`, never invented as zero.

## Quality policy
Default-backend changes must not regress the commit corpus without an explicit benchmark explanation. Fidelity gates dominate speed. MOS predictors are advisory because no-reference MOS can be gamed; WER/CER, phone-level tests, signal defects, and listening tests remain separate axes.

## Error handling
Model download/load errors, unsupported symbols, missing conditioning inputs, invalid corpus records, failed synthesis, and malformed benchmark output abort with non-zero status. No backend silently falls back to another backend.

## Testing
Pure logic is unit-tested without model downloads. Model-dependent synthesis and ASR are exercised by the benchmark command. The pre-commit hook runs unit tests before the commit benchmark.

## CI and benchmark website
GitHub Actions runs on an Apple-Silicon macOS runner so Core ML synthesis is exercised on the architecture the project targets. Every push/PR builds and tests; the default branch additionally runs the commit benchmark, uploads raw JSON/audio artifacts, builds a static benchmark/documentation site, and deploys it with GitHub Pages.

The site is derived from repository truth rather than a separately-mutated database. The generator walks git history with full checkout depth and parses `BENCHMARK_RESULTS.md` from each commit, producing a chronological `history.json`. This guarantees historical graphs correspond to immutable commits.

The Pages site contains:
- current headline quality/performance metrics and gate status;
- benchmark trends across commits with links to commit SHAs;
- per-sample benchmark table and current synthesized WAV examples with HTML audio controls;
- benchmark methodology/schema documentation;
- CLI/library usage documentation and architecture notes.

CI uses official GitHub Pages actions (`configure-pages@v5`, `upload-pages-artifact@v4`, `deploy-pages@v4`) and a full-history checkout. The benchmark job publishes its JSON and WAV outputs as normal workflow artifacts as well as embedding selected examples in the Pages artifact.
