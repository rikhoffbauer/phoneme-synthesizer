---
aggregate:
  backend: kokoro-ane
  cer: 0
  clipping_ratio: 0
  dc_offset: -0.000004004309274352058
  rtfx: 9.377269886243697
  score: 100
  utmos: null
  wer: 0
backends:
  - available: true
    backend: kokoro-ane
    note: measured in this run
  - available: false
    backend: luxtts
    note: not measured in this run
  - available: false
    backend: styletts2
    note: not measured in this run
  - available: false
    backend: inflect-v2
    note: not measured in this run
  - available: false
    backend: toucan-articulatory
    note: not measured in this run
benchmark_version: 1
corpus:
  path: Benchmarks/corpus/commit.jsonl
  samples: 12
  sha256: c9a5021392b5af20b4b54c9de584a6043ad99fa35d919f7d125d25af24f4b622
gates:
  failures: []
  passed: true
generated_at: 2026-09-06T21:34:29Z
git:
  branch: main
  commit: null
  tree: aa56481119481d75dd25d0c5c115754f96bdcb19
profile: commit
samples:
  - audio_file: 01-en-01.wav
    audio_ms: 1625
    cer: 0
    clipping_ratio: 0
    dc_offset: -0.000025234941784389582
    id: en-01
    ipa: həlˈoʊ wˈɜːld
    peak: 0.27349239587783813
    rms: 0.04602869677518026
    rtfx: 1.0669026183413917
    synth_ms: 1523.100583
    text: Hello world.
    wer: 0
  - audio_file: 02-en-02.wav
    audio_ms: 3300
    cer: 0
    clipping_ratio: 0
    dc_offset: -0.000005545204305343831
    id: en-02
    ipa: ðə kwˈɪk bɹˈaʊn fˈɑːks dʒˈʌmps ˌoʊvɚ ðə lˈeɪzi dˈɑːɡ
    peak: 0.36285555362701416
    rms: 0.04789027983900187
    rtfx: 23.981860992413008
    synth_ms: 137.604
    text: The quick brown fox jumps over the lazy dog.
    wer: 0
  - audio_file: 03-en-03.wav
    audio_ms: 2750
    cer: 0
    clipping_ratio: 0
    dc_offset: -0.000015758902082733924
    id: en-03
    ipa: fɹˈɛʃ bɹˈɛd smˈɛlz wˈʌndɚfəl ɪnðə mˈɔːɹnɪŋ
    peak: 0.4621676206588745
    rms: 0.04591404787903087
    rtfx: 18.299108875984757
    synth_ms: 150.280542
    text: Fresh bread smells wonderful in the morning.
    wer: 0
  - audio_file: 04-en-04.wav
    audio_ms: 2475
    cer: 0
    clipping_ratio: 0
    dc_offset: 0.000006049365678619046
    id: en-04
    ipa: ʃiː sˈɛlz sˈiːʃɛlz baɪ ðə sˈiːʃɔːɹ
    peak: 0.3734591007232666
    rms: 0.044961471886915495
    rtfx: 15.539137436607383
    synth_ms: 159.27525
    text: She sells seashells by the seashore.
    wer: 0
  - audio_file: 05-en-05.wav
    audio_ms: 2725
    cer: 0
    clipping_ratio: 0
    dc_offset: 0.000004211466179017099
    id: en-05
    ipa: θɹˈiː θˈɪn θˈiːvz θˈɔːt ɐ θˈaʊzənd θˈɔːts
    peak: 0.35276833176612854
    rms: 0.047188400282198784
    rtfx: 17.511198234552484
    synth_ms: 155.61470799999998
    text: Three thin thieves thought a thousand thoughts.
    wer: 0
  - audio_file: 06-en-06.wav
    audio_ms: 3175
    cer: 0
    clipping_ratio: 0
    dc_offset: -0.0000010919844465753488
    id: en-06
    ipa: dʒˈɔːɹdʒ tʃˈoʊz ɐ dʒˈaɪənt dʒˈɑːɹ ʌv ˈɔɹɪndʒ dʒˈæm
    peak: 0.3329154849052429
    rms: 0.0453988796423441
    rtfx: 18.860746516544864
    synth_ms: 168.339042
    text: George chose a giant jar of orange jam.
    wer: 0
  - audio_file: 07-en-07.wav
    audio_ms: 2950
    cer: 0
    clipping_ratio: 0
    dc_offset: -0.000011700162104607283
    id: en-07
    ipa: wiː ɹˈɛɹli ɹˈiəli wˈʌɹi ɐbˌaʊt ɹˈʊɹɹəl ɹˈoʊdz
    peak: 0.39686158299446106
    rms: 0.04333937475368937
    rtfx: 18.95876228202444
    synth_ms: 155.600875
    text: We rarely really worry about rural roads.
    wer: 0
  - audio_file: 08-en-08.wav
    audio_ms: 3150
    cer: 0
    clipping_ratio: 0
    dc_offset: 0.0000028372446628303614
    id: en-08
    ipa: plˈiːz bɹˈɪŋ bɹˈaɪt blˈuː flˈaʊɚz bᵻfˌɔːɹ bɹˈɛkfəst
    peak: 0.32087409496307373
    rms: 0.04796948261701165
    rtfx: 19.003101288032017
    synth_ms: 165.762417
    text: Please bring bright blue flowers before breakfast.
    wer: 0
  - audio_file: 09-en-09.wav
    audio_ms: 2925
    cer: 0
    clipping_ratio: 0
    dc_offset: -0.000008368332295888992
    id: en-09
    ipa: ɐ nˈɔɪzi tɹˈeɪn kɹˈɔst ðə bɹˈɪdʒ æt mˈɪdnaɪt
    peak: 0.3996948301792145
    rms: 0.04924054192985914
    rtfx: 18.492663445145645
    synth_ms: 158.170834
    text: A noisy train crossed the bridge at midnight.
    wer: 0
  - audio_file: 10-en-10.wav
    audio_ms: 2675
    cer: 0
    clipping_ratio: 0
    dc_offset: -3.037127563944529e-8
    id: en-10
    ipa: kʊd juː mˈɛʒɚ ðə tˈɛmpɹɪtʃɚ pɹɪsˈaɪsli
    peak: 0.36606651544570923
    rms: 0.048824577900769627
    rtfx: 16.972591979567714
    synth_ms: 157.607041
    text: Could you measure the temperature precisely?
    wer: 0
  - audio_file: 11-en-11.wav
    audio_ms: 3225
    cer: 0
    clipping_ratio: 0
    dc_offset: -0.000006440166361536697
    id: en-11
    ipa: ðə dʒˈʌdʒ kˈɑːmli ˈæskt wˈɛðɚɹ ˈɛvɹɪwˌʌn ɐɡɹˈiːd
    peak: 0.4881881773471832
    rms: 0.04702601932260523
    rtfx: 18.013409584254358
    synth_ms: 179.03329100000002
    text: The judge calmly asked whether everyone agreed.
    wer: 0
  - audio_file: 12-en-12.wav
    audio_ms: 3425
    cer: 0
    clipping_ratio: 0
    dc_offset: 0.000013020276844023896
    id: en-12
    ipa: vˈɔɪs kwˈɔlᵻɾi mˈæɾɚz wɛn sˈʌɾəl sˈaʊndz dˈɪfɚ
    peak: 0.34968435764312744
    rms: 0.04765346243544293
    rtfx: 6.137370933284391
    synth_ms: 558.056542
    text: Voice quality matters when subtle sounds differ.
    wer: 0
schema_version: 1
system:
  arch: arm64
  hardware: Mac16,12
  os: Version 27.0 (Build 26A5388g)
---

# Benchmark Results

| Metric | Result |
| --- | ---: |
| Score | 100.00 |
| Backend | `kokoro-ane` |
| WER | 0.00% |
| CER | 0.00% |
| UTMOS | not measured |
| RTFx | 9.38× |
| Clipping ratio | 0.00% |
| DC offset | -4.004e-6 |

All benchmark gates passed.

Profile: `commit` · corpus: `Benchmarks/corpus/commit.jsonl` (12 samples) · tree: `aa56481119481d75dd25d0c5c115754f96bdcb19`
