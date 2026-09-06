# Phone symbol support

This matrix describes raw `--ipa` input behavior for the synthesis backends pinned by this repository.
The baseline is the International Phonetic Alphabet chart revised to 2020; backend-specific extensions are listed separately.

## Legend

- `T` — tokenized/reachable. This does **not** by itself prove correct IPA acoustic realization.
- `F` — represented explicitly as an articulatory feature by Toucan (stronger semantic support than token presence).
- `M` — our strict adapter maps the IPA symbol to an equivalent Toucan articulatory representation.
- `C` — supported only in explicitly recognized contexts; bare use remains invalid.
- `⚠` — token/vocabulary entry exists, but the pinned tokenizer loses it in normal use.
- `—` — unsupported by the strict raw-phone path; it must error rather than be silently dropped.

Reference conditioning is orthogonal to symbol support: LuxTTS and StyleTTS2 still require their normal reference-audio inputs. `T` never means “phonetically validated.”

## Verification provenance

- Kokoro runtime `vocab.json`: `8d65b0188b77eafc60751dac42bbac7ab5f5685074af44db91d1877b42dc1d7c` (114 entries; exact set match)
- LuxTTS pinned `tokens.txt`: `ce98c1afc5f7a20c2484dffdd68a1fff0a4a2cc707328833750c4476c37cdbda` (360 tokens; 159 raw single-scalar tokens)
- Local strict wrappers: LuxTTS 159/159 exact match; Inflect v2 177/177 exact match
- FluidAudio revision: `5c19d5e12320e22bbfb7a1877b089d2665a69add`
- StyleTTS2 fixed symbol table: 177 unique Unicode scalars
- Inflect v2 fixed symbol table: 177 unique Unicode scalars
- IMS Toucan installed source: `3cc2094d9c7123336eda7e299ac0bc90319ca9ff`; direct symbol table exact-match verified
- IMS Toucan articulatory audit revision: `3cc2094d9c7123336eda7e299ac0bc90319ca9ff`; 111 direct symbols plus semantic modifiers/mappings
- IPA baseline: International Phonetic Association, official chart revised to 2020.
- Kokoro combining-mark diagnostic: `KokoroAneVocab.encode("æ̃")` produced only BOS/EOS even though `̃` exists in `vocab.json`.
- StyleTTS2 combining-mark diagnostic: `StyleTTS2TextCleaner.dictionary["̩"] == nil`; `n̩` encodes to no phoneme tokens.

## Important compatibility findings

1. **Kokoro does not natively support `˞` or `ɝ`.** Its own English G2P emits rhotic sequences such as `ɜɹ` and `əɹ`; `ɚ` is a native token.
2. **LuxTTS supports `˞` but not `ɝ`.** It also has the broadest set of directly usable combining IPA diacritics here.
3. **StyleTTS2 and Inflect v2 contain all 108 base IPA chart symbols**, including `ɝ` and `˞` as backend extensions, but StyleTTS2 has a combining-mark grapheme bug for syllabicity `̩`.
4. **Kokoro's `̃` token is not effectively usable as a combining nasalization mark** in the pinned FluidAudio revision because its tokenizer iterates Swift `Character` grapheme clusters.
5. **Toucan is different:** modifiers such as `ʰ`, `̃`, and `ʷ` mutate explicit articulatory features. Our adapter also provides strict equivalence mappings for `ɥ→jʷ`, `ⱱ→ѵ` (Toucan's labiodental-flap table typo), `ʲ→̧`, and `ˤ→ˁ`. We deliberately do not use Toucan's lossy text-frontend approximations for `ɬ`, `ɮ`, `ɺ`, or `ɧ`.
6. **Acoustic validation is tracked separately from reachability.** For example, Inflect v2 `ʷ` has been synthesis-exercised (`ka` and `kʷa` produce different audio), but correct labialization has not yet been independently established.

## Base IPA symbols

Coverage across the 108 base consonant/vowel/other symbols on the IPA 2020 chart:

| Backend | Supported | Missing |
|---|---:|---|
| Kokoro ANE | 71/108 | `ħ ǀ ǁ ǂ ǃ ɓ ɗ ɘ ɞ ɠ ɢ ɦ ɧ ɬ ɭ ɮ ɱ ɵ ɶ ɺ ʀ ʄ ʉ ʍ ʏ ʐ ʑ ʕ ʘ ʙ ʛ ʜ ʟ ʡ ʢ ʼ ⱱ` |
| LuxTTS | 107/108 | `ʼ` |
| StyleTTS2 | 108/108 | `—` |
| Inflect v2 | 108/108 | `—` |
| Toucan articulatory | 104/108 | `ɧ ɬ ɮ ɺ` |

### Pulmonic consonants

| Symbol | Unicode | Description | Kokoro ANE | LuxTTS | StyleTTS2 | Inflect v2 | Toucan |
|---|---|---|:---:|:---:|:---:|:---:|:---:|
| `p` | `U+0070` | Latin Small Letter P | T | T | T | T | T |
| `b` | `U+0062` | Latin Small Letter B | T | T | T | T | T |
| `t` | `U+0074` | Latin Small Letter T | T | T | T | T | T |
| `d` | `U+0064` | Latin Small Letter D | T | T | T | T | T |
| `ʈ` | `U+0288` | Latin Small Letter T With Retroflex Hook | T | T | T | T | T |
| `ɖ` | `U+0256` | Latin Small Letter D With Tail | T | T | T | T | T |
| `c` | `U+0063` | Latin Small Letter C | T | T | T | T | T |
| `ɟ` | `U+025F` | Latin Small Letter Dotless J With Stroke | T | T | T | T | T |
| `k` | `U+006B` | Latin Small Letter K | T | T | T | T | T |
| `ɡ` | `U+0261` | Latin Small Letter Script G | T | T | T | T | T |
| `q` | `U+0071` | Latin Small Letter Q | T | T | T | T | T |
| `ɢ` | `U+0262` | Latin Letter Small Capital G | — | T | T | T | T |
| `ʔ` | `U+0294` | Latin Letter Glottal Stop | T | T | T | T | T |
| `m` | `U+006D` | Latin Small Letter M | T | T | T | T | T |
| `ɱ` | `U+0271` | Latin Small Letter M With Hook | — | T | T | T | T |
| `n` | `U+006E` | Latin Small Letter N | T | T | T | T | T |
| `ɳ` | `U+0273` | Latin Small Letter N With Retroflex Hook | T | T | T | T | T |
| `ɲ` | `U+0272` | Latin Small Letter N With Left Hook | T | T | T | T | T |
| `ŋ` | `U+014B` | Latin Small Letter Eng | T | T | T | T | T |
| `ɴ` | `U+0274` | Latin Letter Small Capital N | T | T | T | T | T |
| `ʙ` | `U+0299` | Latin Letter Small Capital B | — | T | T | T | T |
| `r` | `U+0072` | Latin Small Letter R | T | T | T | T | T |
| `ʀ` | `U+0280` | Latin Letter Small Capital R | — | T | T | T | T |
| `ⱱ` | `U+2C71` | Latin Small Letter V With Right Hook | — | T | T | T | M |
| `ɾ` | `U+027E` | Latin Small Letter R With Fishhook | T | T | T | T | T |
| `ɽ` | `U+027D` | Latin Small Letter R With Tail | T | T | T | T | T |
| `ɸ` | `U+0278` | Latin Small Letter Phi | T | T | T | T | T |
| `β` | `U+03B2` | Greek Small Letter Beta | T | T | T | T | T |
| `f` | `U+0066` | Latin Small Letter F | T | T | T | T | T |
| `v` | `U+0076` | Latin Small Letter V | T | T | T | T | T |
| `θ` | `U+03B8` | Greek Small Letter Theta | T | T | T | T | T |
| `ð` | `U+00F0` | Latin Small Letter Eth | T | T | T | T | T |
| `s` | `U+0073` | Latin Small Letter S | T | T | T | T | T |
| `z` | `U+007A` | Latin Small Letter Z | T | T | T | T | T |
| `ʃ` | `U+0283` | Latin Small Letter Esh | T | T | T | T | T |
| `ʒ` | `U+0292` | Latin Small Letter Ezh | T | T | T | T | T |
| `ʂ` | `U+0282` | Latin Small Letter S With Hook | T | T | T | T | T |
| `ʐ` | `U+0290` | Latin Small Letter Z With Retroflex Hook | — | T | T | T | T |
| `ç` | `U+00E7` | Latin Small Letter C With Cedilla | T | T | T | T | T |
| `ʝ` | `U+029D` | Latin Small Letter J With Crossed-Tail | T | T | T | T | T |
| `x` | `U+0078` | Latin Small Letter X | T | T | T | T | T |
| `ɣ` | `U+0263` | Latin Small Letter Gamma | T | T | T | T | T |
| `χ` | `U+03C7` | Greek Small Letter Chi | T | T | T | T | T |
| `ʁ` | `U+0281` | Latin Letter Small Capital Inverted R | T | T | T | T | T |
| `ħ` | `U+0127` | Latin Small Letter H With Stroke | — | T | T | T | T |
| `ʕ` | `U+0295` | Latin Letter Pharyngeal Voiced Fricative | — | T | T | T | T |
| `h` | `U+0068` | Latin Small Letter H | T | T | T | T | T |
| `ɦ` | `U+0266` | Latin Small Letter H With Hook | — | T | T | T | T |
| `ɬ` | `U+026C` | Latin Small Letter L With Belt | — | T | T | T | — |
| `ɮ` | `U+026E` | Latin Small Letter Lezh | — | T | T | T | — |
| `ʋ` | `U+028B` | Latin Small Letter V With Hook | T | T | T | T | T |
| `ɹ` | `U+0279` | Latin Small Letter Turned R | T | T | T | T | T |
| `ɻ` | `U+027B` | Latin Small Letter Turned R With Hook | T | T | T | T | T |
| `j` | `U+006A` | Latin Small Letter J | T | T | T | T | T |
| `ɰ` | `U+0270` | Latin Small Letter Turned M With Long Leg | T | T | T | T | T |
| `l` | `U+006C` | Latin Small Letter L | T | T | T | T | T |
| `ɭ` | `U+026D` | Latin Small Letter L With Retroflex Hook | — | T | T | T | T |
| `ʎ` | `U+028E` | Latin Small Letter Turned Y | T | T | T | T | T |
| `ʟ` | `U+029F` | Latin Letter Small Capital L | — | T | T | T | T |

### Non-pulmonic consonants

| Symbol | Unicode | Description | Kokoro ANE | LuxTTS | StyleTTS2 | Inflect v2 | Toucan |
|---|---|---|:---:|:---:|:---:|:---:|:---:|
| `ʘ` | `U+0298` | Latin Letter Bilabial Click | — | T | T | T | T |
| `ǀ` | `U+01C0` | Latin Letter Dental Click | — | T | T | T | T |
| `ǃ` | `U+01C3` | Latin Letter Retroflex Click | — | T | T | T | T |
| `ǂ` | `U+01C2` | Latin Letter Alveolar Click | — | T | T | T | T |
| `ǁ` | `U+01C1` | Latin Letter Lateral Click | — | T | T | T | T |
| `ɓ` | `U+0253` | Latin Small Letter B With Hook | — | T | T | T | T |
| `ɗ` | `U+0257` | Latin Small Letter D With Hook | — | T | T | T | T |
| `ʄ` | `U+0284` | Latin Small Letter Dotless J With Stroke And Hook | — | T | T | T | T |
| `ɠ` | `U+0260` | Latin Small Letter G With Hook | — | T | T | T | T |
| `ʛ` | `U+029B` | Latin Letter Small Capital G With Hook | — | T | T | T | T |
| `ʼ` | `U+02BC` | Modifier Letter Apostrophe | — | — | T | T | F |

### Other IPA symbols

| Symbol | Unicode | Description | Kokoro ANE | LuxTTS | StyleTTS2 | Inflect v2 | Toucan |
|---|---|---|:---:|:---:|:---:|:---:|:---:|
| `ʍ` | `U+028D` | Latin Small Letter Turned W | — | T | T | T | T |
| `w` | `U+0077` | Latin Small Letter W | T | T | T | T | T |
| `ɥ` | `U+0265` | Latin Small Letter Turned H | T | T | T | T | M |
| `ʜ` | `U+029C` | Latin Letter Small Capital H | — | T | T | T | T |
| `ʢ` | `U+02A2` | Latin Letter Reversed Glottal Stop With Stroke | — | T | T | T | T |
| `ʡ` | `U+02A1` | Latin Letter Glottal Stop With Stroke | — | T | T | T | T |
| `ɕ` | `U+0255` | Latin Small Letter C With Curl | T | T | T | T | T |
| `ʑ` | `U+0291` | Latin Small Letter Z With Curl | — | T | T | T | T |
| `ɺ` | `U+027A` | Latin Small Letter Turned R With Long Leg | — | T | T | T | — |
| `ɧ` | `U+0267` | Latin Small Letter Heng With Hook | — | T | T | T | — |

### Vowels

| Symbol | Unicode | Description | Kokoro ANE | LuxTTS | StyleTTS2 | Inflect v2 | Toucan |
|---|---|---|:---:|:---:|:---:|:---:|:---:|
| `i` | `U+0069` | Latin Small Letter I | T | T | T | T | T |
| `y` | `U+0079` | Latin Small Letter Y | T | T | T | T | T |
| `ɨ` | `U+0268` | Latin Small Letter I With Stroke | T | T | T | T | T |
| `ʉ` | `U+0289` | Latin Small Letter U Bar | — | T | T | T | T |
| `ɯ` | `U+026F` | Latin Small Letter Turned M | T | T | T | T | T |
| `u` | `U+0075` | Latin Small Letter U | T | T | T | T | T |
| `ɪ` | `U+026A` | Latin Letter Small Capital I | T | T | T | T | T |
| `ʏ` | `U+028F` | Latin Letter Small Capital Y | — | T | T | T | T |
| `ʊ` | `U+028A` | Latin Small Letter Upsilon | T | T | T | T | T |
| `e` | `U+0065` | Latin Small Letter E | T | T | T | T | T |
| `ø` | `U+00F8` | Latin Small Letter O With Stroke | T | T | T | T | T |
| `ɘ` | `U+0258` | Latin Small Letter Reversed E | — | T | T | T | T |
| `ɵ` | `U+0275` | Latin Small Letter Barred O | — | T | T | T | T |
| `ɤ` | `U+0264` | Latin Small Letter Rams Horn | T | T | T | T | T |
| `o` | `U+006F` | Latin Small Letter O | T | T | T | T | T |
| `ə` | `U+0259` | Latin Small Letter Schwa | T | T | T | T | T |
| `ɛ` | `U+025B` | Latin Small Letter Open E | T | T | T | T | T |
| `œ` | `U+0153` | Latin Small Ligature Oe | T | T | T | T | T |
| `ɜ` | `U+025C` | Latin Small Letter Reversed Open E | T | T | T | T | T |
| `ɞ` | `U+025E` | Latin Small Letter Closed Reversed Open E | — | T | T | T | T |
| `ʌ` | `U+028C` | Latin Small Letter Turned V | T | T | T | T | T |
| `ɔ` | `U+0254` | Latin Small Letter Open O | T | T | T | T | T |
| `æ` | `U+00E6` | Latin Small Letter Ae | T | T | T | T | T |
| `ɐ` | `U+0250` | Latin Small Letter Turned A | T | T | T | T | T |
| `a` | `U+0061` | Latin Small Letter A | T | T | T | T | T |
| `ɶ` | `U+0276` | Latin Letter Small Capital Oe | — | T | T | T | T |
| `ɑ` | `U+0251` | Latin Small Letter Alpha | T | T | T | T | T |
| `ɒ` | `U+0252` | Latin Small Letter Turned Alpha | T | T | T | T | T |

## IPA diacritics

| Symbol | Unicode | Description | Kokoro ANE | LuxTTS | StyleTTS2 | Inflect v2 | Toucan |
|---|---|---|:---:|:---:|:---:|:---:|:---:|
| `◌̥` | `U+0325` | Voiceless (below) | — | — | — | — | F |
| `◌̊` | `U+030A` | Voiceless (above) | — | T | — | — | — |
| `◌̬` | `U+032C` | Voiced | — | — | — | — | F |
| `ʰ` | `U+02B0` | Aspirated | T | T | T | T | F |
| `◌̹` | `U+0339` | More rounded | — | — | — | — | F |
| `◌̜` | `U+031C` | Less rounded | — | — | — | — | F |
| `◌̟` | `U+031F` | Advanced | — | — | — | — | — |
| `◌̠` | `U+0320` | Retracted | — | — | — | — | — |
| `◌̈` | `U+0308` | Centralized | — | — | — | — | F |
| `◌̽` | `U+033D` | Mid-centralized | — | — | — | — | — |
| `◌̩` | `U+0329` | Syllabic | — | T | ⚠ | T | — |
| `◌̯` | `U+032F` | Non-syllabic | — | T | — | — | — |
| `˞` | `U+02DE` | Rhoticity | — | T | T | T | C |
| `◌̤` | `U+0324` | Breathy voiced | — | — | — | — | — |
| `◌̰` | `U+0330` | Creaky voiced | — | — | — | — | F |
| `◌̼` | `U+033C` | Linguolabial | — | — | — | — | — |
| `ʷ` | `U+02B7` | Labialized | — | — | T | T | F |
| `ʲ` | `U+02B2` | Palatalized | T | T | T | T | M |
| `ˠ` | `U+02E0` | Velarized | — | — | T | T | F |
| `ˤ` | `U+02E4` | Pharyngealized | — | T | T | T | M |
| `◌̴` | `U+0334` | Velarized/pharyngealized | — | — | — | — | — |
| `◌̝` | `U+031D` | Raised | — | T | — | — | F |
| `◌̞` | `U+031E` | Lowered | — | — | — | — | F |
| `◌̘` | `U+0318` | Advanced tongue root | — | — | — | — | — |
| `◌̙` | `U+0319` | Retracted tongue root | — | — | — | — | — |
| `◌̪` | `U+032A` | Dental | — | T | — | — | F |
| `◌̺` | `U+033A` | Apical | — | T | — | — | — |
| `◌̻` | `U+033B` | Laminal | — | T | — | — | — |
| `◌̃` | `U+0303` | Nasalized | ⚠ | T | — | — | F |
| `ⁿ` | `U+207F` | Nasal release | — | — | — | — | — |
| `ˡ` | `U+02E1` | Lateral release | — | — | — | — | — |
| `◌̚` | `U+031A` | No audible release | — | — | — | — | — |
| `◌͡` | `U+0361` | Tie bar above | — | — | — | — | — |
| `◌͜` | `U+035C` | Tie bar below | — | — | — | — | — |

> `⚠` is materially different from `T`: the scalar exists in the vocabulary, but the current tokenizer loses it when attached to its base phone.

## Suprasegmentals

| Symbol | Unicode | Description | Kokoro ANE | LuxTTS | StyleTTS2 | Inflect v2 | Toucan |
|---|---|---|:---:|:---:|:---:|:---:|:---:|
| `ˈ` | `U+02C8` | Primary stress | T | T | T | T | F |
| `ˌ` | `U+02CC` | Secondary stress | T | T | T | T | M |
| `ː` | `U+02D0` | Long | T | T | T | T | F |
| `ˑ` | `U+02D1` | Half-long | — | T | T | T | F |
| `◌̆` | `U+0306` | Extra-short | — | — | — | — | F |
| <code>&#124;</code> | `U+007C` | Minor group | — | — | — | — | — |
| `‖` | `U+2016` | Major group | — | — | — | — | — |
| `.` | `U+002E` | Syllable break | T | T | T | T | T |
| `‿` | `U+203F` | Linking | — | — | — | — | — |

## Tones and word accents

| Symbol | Unicode | Description | Kokoro ANE | LuxTTS | StyleTTS2 | Inflect v2 | Toucan |
|---|---|---|:---:|:---:|:---:|:---:|:---:|
| `˥` | `U+02E5` | Extra high tone letter | — | — | — | — | F |
| `˦` | `U+02E6` | High tone letter | — | — | — | — | F |
| `˧` | `U+02E7` | Mid tone letter | — | — | — | — | F |
| `˨` | `U+02E8` | Low tone letter | — | — | — | — | F |
| `˩` | `U+02E9` | Extra low tone letter | — | — | — | — | F |
| `◌̋` | `U+030B` | Extra high tone diacritic | — | — | — | — | — |
| `◌́` | `U+0301` | High tone diacritic | — | — | — | — | — |
| `◌̄` | `U+0304` | Mid tone diacritic | — | — | — | — | — |
| `◌̀` | `U+0300` | Low tone diacritic | — | — | — | — | — |
| `◌̏` | `U+030F` | Extra low tone diacritic | — | — | — | — | — |
| `◌̌` | `U+030C` | Rising | — | — | — | — | — |
| `◌̂` | `U+0302` | Falling | — | — | — | — | — |
| `◌᷄` | `U+1DC4` | High rising | — | — | — | — | — |
| `◌᷅` | `U+1DC5` | Low rising | — | — | — | — | — |
| `◌᷈` | `U+1DC8` | Rising-falling | — | — | — | — | — |
| `↓` | `U+2193` | Downstep | T | T | T | T | — |
| `↑` | `U+2191` | Upstep | — | T | T | T | — |
| `↗` | `U+2197` | Global rise | T | — | T | T | — |
| `↘` | `U+2198` | Global fall | T | — | T | T | — |

## Backend-specific and non-IPA raw tokens

These are single-scalar tokens accepted by at least one backend but not a standalone symbol in the IPA 2020 baseline above. Some are espeak/training conventions, punctuation, control tokens, or language-specific extensions rather than phones.

| Token | Unicode | Unicode name | Kokoro ANE | LuxTTS | StyleTTS2 | Inflect v2 | Toucan |
|---|---|---|:---:|:---:|:---:|:---:|:---:|
| `SPACE` | `U+0020` | Space | T | T | T | T | T |
| `!` | `U+0021` | Exclamation Mark | T | T | T | T | T |
| `"` | `U+0022` | Quotation Mark | T | T | T | T | — |
| `#` | `U+0023` | Number Sign | — | T | — | — | T |
| `$` | `U+0024` | Dollar Sign | — | T | T | — | — |
| `'` | `U+0027` | Apostrophe | — | T | T | T | — |
| `(` | `U+0028` | Left Parenthesis | T | T | — | — | — |
| `)` | `U+0029` | Right Parenthesis | T | T | — | — | — |
| `,` | `U+002C` | Comma | T | T | T | T | — |
| `-` | `U+002D` | Hyphen-Minus | — | T | — | — | — |
| `0` | `U+0030` | Digit Zero | — | T | — | — | — |
| `1` | `U+0031` | Digit One | — | T | — | — | — |
| `2` | `U+0032` | Digit Two | — | T | — | — | — |
| `3` | `U+0033` | Digit Three | — | T | — | — | — |
| `4` | `U+0034` | Digit Four | — | T | — | — | — |
| `5` | `U+0035` | Digit Five | — | T | — | — | — |
| `6` | `U+0036` | Digit Six | — | T | — | — | — |
| `7` | `U+0037` | Digit Seven | — | T | — | — | — |
| `8` | `U+0038` | Digit Eight | — | T | — | — | — |
| `9` | `U+0039` | Digit Nine | — | T | — | — | — |
| `:` | `U+003A` | Colon | T | T | T | T | — |
| `;` | `U+003B` | Semicolon | T | T | T | T | — |
| `?` | `U+003F` | Question Mark | T | T | T | T | T |
| `A` | `U+0041` | Latin Capital Letter A | T | — | T | T | — |
| `B` | `U+0042` | Latin Capital Letter B | — | — | T | T | — |
| `C` | `U+0043` | Latin Capital Letter C | — | — | T | T | — |
| `D` | `U+0044` | Latin Capital Letter D | — | — | T | T | — |
| `E` | `U+0045` | Latin Capital Letter E | — | — | T | T | — |
| `F` | `U+0046` | Latin Capital Letter F | — | — | T | T | — |
| `G` | `U+0047` | Latin Capital Letter G | — | — | T | T | — |
| `H` | `U+0048` | Latin Capital Letter H | — | — | T | T | — |
| `I` | `U+0049` | Latin Capital Letter I | T | — | T | T | — |
| `J` | `U+004A` | Latin Capital Letter J | — | — | T | T | — |
| `K` | `U+004B` | Latin Capital Letter K | — | — | T | T | — |
| `L` | `U+004C` | Latin Capital Letter L | — | — | T | T | — |
| `M` | `U+004D` | Latin Capital Letter M | — | — | T | T | — |
| `N` | `U+004E` | Latin Capital Letter N | — | — | T | T | — |
| `O` | `U+004F` | Latin Capital Letter O | T | — | T | T | — |
| `P` | `U+0050` | Latin Capital Letter P | — | — | T | T | — |
| `Q` | `U+0051` | Latin Capital Letter Q | T | — | T | T | — |
| `R` | `U+0052` | Latin Capital Letter R | — | — | T | T | — |
| `S` | `U+0053` | Latin Capital Letter S | T | — | T | T | — |
| `T` | `U+0054` | Latin Capital Letter T | T | — | T | T | — |
| `U` | `U+0055` | Latin Capital Letter U | — | — | T | T | — |
| `V` | `U+0056` | Latin Capital Letter V | — | — | T | T | — |
| `W` | `U+0057` | Latin Capital Letter W | T | — | T | T | — |
| `X` | `U+0058` | Latin Capital Letter X | — | T | T | T | — |
| `Y` | `U+0059` | Latin Capital Letter Y | T | — | T | T | — |
| `Z` | `U+005A` | Latin Capital Letter Z | — | — | T | T | — |
| `^` | `U+005E` | Circumflex Accent | — | T | — | — | — |
| `_` | `U+005F` | Low Line | — | T | — | T | — |
| `g` | `U+0067` | Latin Small Letter G | — | T | T | T | — |
| `~` | `U+007E` | Tilde | — | — | — | — | T |
| `¡` | `U+00A1` | Inverted Exclamation Mark | — | — | T | T | — |
| `«` | `U+00AB` | Left-Pointing Double Angle Quotation Mark | — | — | T | T | — |
| `»` | `U+00BB` | Right-Pointing Double Angle Quotation Mark | — | — | T | T | — |
| `¿` | `U+00BF` | Inverted Question Mark | — | — | T | T | — |
| `õ` | `U+00F5` | Latin Small Letter O With Tilde | — | — | — | — | T |
| `ĩ` | `U+0129` | Latin Small Letter I With Tilde | — | — | — | — | T |
| `ũ` | `U+0169` | Latin Small Letter U With Tilde | — | — | — | — | T |
| `ɚ` | `U+025A` | Latin Small Letter Schwa With Hook | T | T | T | T | M |
| `ɝ` | `U+025D` | Latin Small Letter Reversed Open E With Hook | — | — | T | T | M |
| `ɫ` | `U+026B` | Latin Small Letter L With Middle Tilde | — | T | T | T | — |
| `ʣ` | `U+02A3` | Latin Small Letter Dz Digraph | T | — | — | — | — |
| `ʤ` | `U+02A4` | Latin Small Letter Dezh Digraph | T | — | T | T | — |
| `ʥ` | `U+02A5` | Latin Small Letter Dz Digraph With Curl | T | — | — | — | — |
| `ʦ` | `U+02A6` | Latin Small Letter Ts Digraph | T | T | — | — | — |
| `ʧ` | `U+02A7` | Latin Small Letter Tesh Digraph | T | — | T | T | — |
| `ʨ` | `U+02A8` | Latin Small Letter Tc Digraph With Curl | T | — | — | — | — |
| `ʱ` | `U+02B1` | Modifier Letter Small H With Hook | — | — | T | T | — |
| `ʴ` | `U+02B4` | Modifier Letter Small Turned R | — | — | T | T | — |
| `◌̧` | `U+0327` | Combining Cedilla | — | T | — | — | F |
| `ε` | `U+03B5` | Greek Small Letter Epsilon | — | T | — | — | — |
| `ѵ` | `U+0475` | Cyrillic Small Letter Izhitsa | — | — | — | — | T |
| `ᵊ` | `U+1D4A` | Modifier Letter Small Schwa | T | — | — | — | — |
| `ᵝ` | `U+1D5D` | Modifier Letter Small Beta | T | — | — | — | — |
| `ᵻ` | `U+1D7B` | Latin Small Capital Letter I With Stroke | T | T | T | T | — |
| `—` | `U+2014` | Em Dash | T | — | T | T | — |
| `“` | `U+201C` | Left Double Quotation Mark | T | — | T | T | — |
| `”` | `U+201D` | Right Double Quotation Mark | T | — | T | T | — |
| `…` | `U+2026` | Horizontal Ellipsis | T | — | T | T | — |
| `→` | `U+2192` | Rightwards Arrow | T | — | T | T | — |
| `ꭧ` | `U+AB67` | Latin Small Letter Ts Digraph With Retroflex Hook | T | — | — | — | — |

## LuxTTS multi-character tokens

The pinned LuxTTS vocabulary also contains **201 multi-character Mandarin/pinyin tokens**. `LuxTtsTokenizer.tokenIds(phonemes:)`, which backs raw English/IPA input, tokenizes one Unicode scalar at a time, so these are **not addressable as atomic tokens through raw `--ipa` strings**. They are reachable only through the token-array API.

```text
a1 a2 a3 a4 a5 ai1 ai2 ai3 ai4 ai5 an1 an2 an3 an4 an5 ang1 ang2 ang3 ang4 ang5
ao1 ao2 ao3 ao4 ao5 b0 c0 ch0 d0 e1 e2 e3 e4 e5 ei1 ei2 ei3 ei4 ei5 en1
en2 en3 en4 en5 eng1 eng2 eng3 eng4 eng5 er2 er3 er4 er5 f0 g0 g2 g3 g4 g5 h0
i1 i2 i3 i4 i5 ia1 ia2 ia3 ia4 ia5 ian1 ian2 ian3 ian4 ian5 iang1 iang2 iang3 iang4 iang5
iao1 iao2 iao3 iao4 iao5 ie1 ie2 ie3 ie4 ie5 in1 in2 in3 in4 in5 ing1 ing2 ing3 ing4 ing5
iong1 iong2 iong3 iong4 iu1 iu2 iu3 iu4 iu5 j0 k0 l0 m0 m1 m2 m4 m5 n0 n2 n3
n4 n5 ng5 o1 o2 o3 o4 o5 ong1 ong2 ong3 ong4 ong5 ou1 ou2 ou3 ou4 ou5 p0 q0
r0 s0 sh0 t0 u1 u2 u3 u4 u5 ua1 ua2 ua3 ua4 uai1 uai2 uai3 uai4 uai5 uan1 uan2
uan3 uan4 uan5 uang1 uang2 uang3 uang4 uang5 ue1 ue2 ue3 ue4 ui1 ui2 ui3 ui4 ui5 un1 un2 un3
un4 un5 uo1 uo2 uo3 uo4 uo5 v2 v3 v4 ve3 ve4 w0 x0 y0 z0 zh0 ê1 ê2 ê3
ê4
```

## Rhotic input conventions

| Form | Kokoro ANE | LuxTTS | StyleTTS2 | Inflect v2 | Toucan | Note |
|---|:---:|:---:|:---:|:---:|:---:|---|
| `ɚ` | T | T | T | T | M | Toucan preserves rhoticity as `əɹ`. |
| `ɝ` | — | — | T | T | M | Toucan preserves rhoticity as `ɜɹ`. |
| `˞` | — | T | T | T | C | Toucan accepts only known rhotic-vowel contexts (`ə˞`, `ɜ˞`); arbitrary `a˞` errors. |
| `ɜɹ`, `əɹ` | T | T | T | T | T | Explicit segment sequences are directly representable. |

For Kokoro, do **not** merely delete `˞`: that removes a phonetic contrast. Convert a known rhotic-vowel spelling to the model's actual phone convention (typically a vowel followed by `ɹ`) or use `ɚ` where appropriate.

## Regeneration

Run `python3 scripts/generate-phone-support.py` after resolving the pinned FluidAudio package. If the downloaded Kokoro runtime vocabulary is present, generation also verifies that its key set exactly matches the repository's strict Kokoro inventory.
