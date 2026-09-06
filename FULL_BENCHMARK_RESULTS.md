---
schema_version: 1
generated_at: 2026-09-06T21:22:25.936Z
benchmark_version: 1
utmos_revision: cc2700db57bb83ee13dc31ebe1b868c254e15d09
git:
  branch: main
  commit: null
  tree: b44c1f2704e0a182cdbfc256ffb83ddb772dcc32
system:
  arch: arm64
  hardware: Mac16,12
  os: Version 27.0 (Build 26A5388g)
corpus:
  path: Benchmarks/corpus/commit.jsonl
  samples: 12
  sha256: c9a5021392b5af20b4b54c9de584a6043ad99fa35d919f7d125d25af24f4b622
source_trees:
  - 24314b93d6a451d458c95b6b6f2e4fe21f8a32af
  - b44c1f2704e0a182cdbfc256ffb83ddb772dcc32
mixed_source_trees: true
backends:
  - backend: kokoro-ane
    score: 100
    wer: 0
    cer: 0
    utmos: 4.023127595583598
    rtfx: 3.07271204626814
    clipping_ratio: 0
    gates_passed: true
    gate_failures: []
    source_tree: b44c1f2704e0a182cdbfc256ffb83ddb772dcc32
    measured_at: 2026-09-06T16:10:50Z
  - backend: luxtts
    score: 97.79716029658404
    wer: 0.012345679012345678
    cer: 0.002403846153846154
    utmos: 3.7471246321996055
    rtfx: 2.5410053834997197
    clipping_ratio: 0
    gates_passed: true
    gate_failures: []
    source_tree: b44c1f2704e0a182cdbfc256ffb83ddb772dcc32
    measured_at: 2026-09-06T16:25:26Z
  - backend: inflect-v2
    score: 53.92792956124162
    wer: 0.12345679012345678
    cer: 0.0673076923076923
    utmos: 3.261984666188558
    rtfx: 7.688399611662157
    clipping_ratio: 0
    gates_passed: false
    gate_failures:
      - WER 12.35% > 8%
      - CER 6.73% > 4%
    source_tree: b44c1f2704e0a182cdbfc256ffb83ddb772dcc32
    measured_at: 2026-09-06T16:14:16Z
  - backend: toucan-articulatory
    score: 18.12542087803285
    wer: 0.2222222222222222
    cer: 0.10576923076923077
    utmos: 2.436562826236089
    rtfx: 0.3334593971418858
    clipping_ratio: 0
    gates_passed: false
    gate_failures:
      - WER 22.22% > 8%
      - CER 10.58% > 4%
      - RTFx 0.33 < 1
    source_tree: 24314b93d6a451d458c95b6b6f2e4fe21f8a32af
    measured_at: 2026-09-06T20:41:58Z
  - backend: styletts2
    score: 10.994291353225709
    wer: 0.2962962962962963
    cer: 0.1658653846153846
    utmos: 2.2970844904581704
    rtfx: 0.3435560771908167
    clipping_ratio: 0
    gates_passed: false
    gate_failures:
      - WER 29.63% > 8%
      - CER 16.59% > 4%
      - RTFx 0.34 < 1
    source_tree: b44c1f2704e0a182cdbfc256ffb83ddb772dcc32
    measured_at: 2026-09-06T16:18:09Z
---

# Full Backend Comparison

| Backend | Score | WER | CER | UTMOS | RTFx | Gates | Tree |
|---|---:|---:|---:|---:|---:|:---:|---|
| `kokoro-ane` | 100.00 | 0.00% | 0.00% | 4.023 | 3.07× | pass | `b44c1f27` |
| `luxtts` | 97.80 | 1.23% | 0.24% | 3.747 | 2.54× | pass | `b44c1f27` |
| `inflect-v2` | 53.93 | 12.35% | 6.73% | 3.262 | 7.69× | fail | `b44c1f27` |
| `toucan-articulatory` | 18.13 | 22.22% | 10.58% | 2.437 | 0.33× | fail | `24314b93` |
| `styletts2` | 10.99 | 29.63% | 16.59% | 2.297 | 0.34× | fail | `b44c1f27` |

> Provenance: this comparison reuses measurements from 2 source trees. Each backend row records its exact measurement tree in YAML frontmatter.

UTMOSv2 revision: `cc2700db57bb83ee13dc31ebe1b868c254e15d09` · corpus: `Benchmarks/corpus/commit.jsonl` (12 samples)
