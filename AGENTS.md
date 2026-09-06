# AGENTS.md

## Project
`phoneme-synthesizer` is a local-first phoneme/IPA to waveform synthesizer optimized for Apple Silicon audio quality.

## Rules
- macOS 14+ and Apple Silicon are the primary target.
- Swift implementation; Bun is used for repository scripts/orchestration.
- Direct phoneme input must never silently drop unsupported symbols.
- Keep synthesis backends behind `PhonemeSynthesisBackend`.
- Benchmarks are product behavior: update `BENCHMARK_RESULTS.md` on commits.
- Use TDD for production behavior and keep benchmark corpora deterministic.
- Prefer objective regression data over subjective tuning guesses.
