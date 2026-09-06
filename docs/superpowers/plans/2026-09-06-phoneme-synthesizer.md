# Phoneme Synthesizer Implementation Plan

> **For agentic workers:** implement task-by-task with TDD and benchmark checkpoints.

**Goal:** Ship a direct-IPA local synthesizer with benchmark results embedded in every commit.

**Architecture:** Swift library + CLI over pinned FluidAudio Core ML backends. Bun orchestrates benchmark report rendering and git hooks. The benchmark corpus and report schema are deterministic and versioned.

**Tech Stack:** Swift 6.4, FluidAudio/Core ML, AVFoundation, Bun + TypeScript, YAML.

**Spec:** `docs/superpowers/specs/2026-09-06-phoneme-synthesizer-design.md`

## Global Constraints
- macOS 14+ / Apple Silicon first.
- Direct IPA input must reject unsupported symbols rather than silently drop them.
- Benchmark frontmatter is machine-readable and schema-versioned.
- A pre-commit hook regenerates and stages `BENCHMARK_RESULTS.md`.
- Benchmark fidelity metrics outrank speed metrics when selecting defaults.

### Task 1: Core types, input normalization, metrics and benchmark report
- Write failing unit tests for IPA delimiter stripping, normalization, empty rejection, Levenshtein/WER/CER, signal metrics, and report serialization.
- Run tests and confirm expected failure.
- Implement minimal library code.
- Run tests to green.

### Task 2: Kokoro phoneme backend + CLI
- Add backend contract tests with a fake backend.
- Implement Kokoro adapter and strict preflight symbol validation.
- Implement `phoneme-synth synth`, `backends`, and WAV writing.
- Verify build and unit tests.

### Task 3: Benchmark harness and machine-readable report
- Add fixed IPA corpus generated with espeak-ng and stored as JSONL.
- Implement benchmark runner using the same backend API as production.
- Add JSON report output and Bun YAML-frontmatter/Markdown renderer.
- Validate report frontmatter with the `yaml` parser.

### Task 4: Commit integration
- Add `.githooks/pre-commit` that runs tests, commit benchmark, report validation, and stages `BENCHMARK_RESULTS.md`.
- Add hook installer script and README instructions.
- Verify hook against a dry-run/manual invocation.

### Task 5: Candidate backend matrix
- Add LuxTTS, StyleTTS2, and Inflect adapters with explicit conditioning requirements.
- Benchmark available candidates on the same IPA corpus.
- Select the default from measured quality/fidelity rather than assumptions.

### Task 6: Quality iteration
- Add UTMOSv2 to full benchmark profile.
- Inspect worst benchmark samples, add regression cases, tune backend/voice/speed only when objective and listening results improve.
- Run full verification and commit with generated benchmark report.

### Task 7: Benchmark history site + GitHub Actions/Pages
- Add tests for benchmark frontmatter parsing and git-history extraction.
- Add a small React/Vite static site fed only by generated JSON, with current metrics, trends, per-sample table, audio examples, and docs.
- Add `scripts/build-site.ts` to extract `BENCHMARK_RESULTS.md` across git history and copy current benchmark audio/examples into the site public data.
- Add `.github/workflows/ci-pages.yml`: Apple-Silicon macOS build/test/benchmark/site job, uploaded benchmark artifact, Pages artifact, and Pages deploy job on `main`.
- Verify the site build locally and validate the workflow YAML structurally.
