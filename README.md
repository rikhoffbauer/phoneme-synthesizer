# phoneme-synthesizer

A benchmark-driven direct-IPA speech synthesizer for Apple Silicon. It accepts phoneme strings directly, renders local Core ML speech, rejects unsupported symbols instead of silently dropping them, and records reproducible benchmark evidence in every commit.

## Backends

| Backend | Output | Conditioning | Direct input |
| --- | ---: | --- | --- |
| `kokoro-ane` | 24 kHz | none | Kokoro/Misaki IPA |
| `luxtts` | 48 kHz | reference WAV + prompt IPA | espeak IPA |
| `styletts2` | 24 kHz | reference WAV | espeak-style IPA |
| `inflect-v2` | 24 kHz | none | espeak/Keith Ito IPA |

Kokoro ANE is the default until a measured full-profile comparison demonstrates a better quality/fidelity trade-off.

## Quick start

```bash
bun install
bun run hooks:install
swift run -c release phoneme-synth backends
swift run -c release phoneme-synth synth \
  --ipa "həlˈoʊ wˈɜːld" \
  --output hello.wav
```

Reference-conditioned example:

```bash
swift run -c release phoneme-synth synth \
  --backend luxtts \
  --ipa "ðə kwˈɪk bɹˈaʊn fˈɑːks" \
  --reference prompt.wav \
  --prompt-phonemes "ɐ kˈɑːm vˈɔɪs spˈiːks" \
  --output out.wav
```

## Benchmarks

`bun run benchmark` runs the deterministic commit corpus in `Benchmarks/corpus/commit.jsonl`, including Parakeet TDT v3 ASR round-trip scoring. It records:

- WER and CER for pronunciation/intelligibility fidelity;
- synthesis latency and RTFx;
- peak, RMS, clipping ratio and DC offset;
- hardware, OS, architecture, corpus SHA-256 and source-tree identity;
- per-sample WAVs and metrics.

`bun run benchmark:full` additionally measures the candidate backend matrix and UTMOSv2 naturalness. UTMOS is advisory rather than a replacement for fidelity tests or listening.

The canonical machine output is `.benchmarks/latest.json`. `BENCHMARK_RESULTS.md` is generated from the same object and begins with schema-versioned YAML frontmatter, so the checked-in report is both human- and machine-readable. Unknown metrics are represented as `null`, never fabricated as zero.

### Commit provenance

A commit cannot contain its own final tree SHA inside a file without creating a self-reference. The pre-commit hook therefore creates a temporary Git index from the staged state, removes only generated `BENCHMARK_RESULTS.md`, calls `git write-tree`, and records that real Git tree object as `git.tree`. Git history supplies the final immutable commit SHA when the website reconstructs historical trends.

### Regression gates

The commit hook fails when any benchmark gate fails. Current gates cover WER, CER, clipping, DC offset and minimum real-time performance. `SKIP_BENCHMARK=1 git commit ...` is an explicit emergency escape hatch and should not be used for normal development.

## Development

```bash
bun test
swift test
swift build -c release
bun run site:build
```

The repository hook (`.githooks/pre-commit`) runs Bun tests, Swift tests, the commit benchmark, validates its gates/schema, and stages `BENCHMARK_RESULTS.md`. Install it once with `bun run hooks:install`.

## Benchmark website / CI

GitHub Actions runs on Apple-Silicon macOS, caches FluidAudio model assets, builds and tests the project, runs the real commit benchmark, uploads JSON/WAV artifacts, then builds the React/Vite benchmark ledger. On pushes to `main`, GitHub Pages deploys that ledger.

History is reconstructed from each commit's immutable `BENCHMARK_RESULTS.md`; there is no separate mutable benchmark database. The site exposes current metrics, per-sample audio, regression status, historical scores and documentation.

## Architecture

- `Sources/PhonemeSynthesizer` — IPA normalization, strict inventories, backend adapters, metrics and benchmark engine.
- `Sources/PhonemeSynthCLI` — `synth`, `benchmark`, and `backends` commands.
- `Benchmarks/corpus` — deterministic benchmark inputs and orthographic ASR references.
- `scripts` — report rendering/validation, git-history extraction, full-profile helpers and site-data generation.
- `site` — static React/Vite benchmark and documentation UI.
- `BENCHMARK_RESULTS.md` — per-commit machine-readable benchmark ledger entry.
