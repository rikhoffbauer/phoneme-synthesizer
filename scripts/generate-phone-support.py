#!/usr/bin/env python3
from __future__ import annotations

import ast
import hashlib
import json
import re
import subprocess
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FLUID = ROOT / ".build/checkouts/FluidAudio"
OUT = ROOT / "docs/PHONE_SYMBOL_SUPPORT.md"
KOKORO_RUNTIME = Path.home() / ".cache/fluidaudio/Models/kokoro-82m-coreml/ANE/vocab.json"
LUX_TOKENS = FLUID / "Tests/FluidAudioTests/TTS/LuxTts/Resources/tokens.txt"

# Audited against DigitalPhonetics/IMS-Toucan at this exact revision.
TOUCAN_REVISION = "3cc2094d9c7123336eda7e299ac0bc90319ca9ff"
TOUCAN_DIRECT = set("~#?!. ɜəaðɛɪŋɔɒɾʃθʊʌʒæbʔdefɡhijklmnɳopɹrstuvwxzʀøçɐœyʏɑcɲɣʎβʝɟqɕɭɵʑʋʁɨʂɓʙɗɖχʛʟɽɢɠǂɦǁĩʍʕɻʄũɤɶõʡʈʜɱɯǀɸʘʐɰɘħɞʉɴʢѵǃ")
TOUCAN_FEATURE_MODIFIERS = set("ˈːˑ̧̆̃ʷʰˠˁˀʼ̹̞̪̬̝̰̜̥̈˥˦˧˨˩⭧⭨⮁⮃")
TOUCAN_MAPPED = {"ɥ", "ⱱ", "ʲ", "ˤ", "ɚ", "ɝ", "ˌ"}
TOUCAN_CONTEXTUAL = {"˞"}
TOUCAN_BASE_ALIASES = {"ɥ", "ⱱ", "ʼ"}
TOUCAN_REPO = Path.home() / ".cache/phoneme-synthesizer/toucan/IMS-Toucan"


def swift_string(path: Path, name: str) -> str:
    source = path.read_text()
    match = re.search(
        rf"(?:let|var)\s+{re.escape(name)}(?:\s*:\s*String)?\s*=\s*(?:Set\()?\s*\n?\s*\"((?:\\.|[^\"\\])*)\"",
        source,
        re.S,
    )
    if not match:
        raise RuntimeError(f"could not find Swift string {name} in {path}")
    raw = re.sub(r"\\u\{([0-9A-Fa-f]+)\}", lambda m: chr(int(m.group(1), 16)), match.group(1))
    return raw.replace('\\"', '"').replace("\\\\", "\\")


def scalar_set(value: str) -> set[str]:
    return {chr(scalar) for scalar in map(ord, value)}


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def git_revision(path: Path) -> str:
    return subprocess.check_output(["git", "-C", str(path), "rev-parse", "HEAD"], text=True).strip()


def load_inventories() -> tuple[dict[str, set[str]], list[str]]:
    kokoro_source = ROOT / "Sources/PhonemeSynthesizer/KokoroPhonemeInventory.swift"
    kokoro = scalar_set(swift_string(kokoro_source, "symbols"))
    verification: list[str] = []
    if KOKORO_RUNTIME.exists():
        runtime = set(json.loads(KOKORO_RUNTIME.read_text()).keys())
        if runtime != kokoro:
            raise RuntimeError("Kokoro wrapper inventory does not match downloaded vocab.json")
        verification.append(f"Kokoro runtime `vocab.json`: `{sha256(KOKORO_RUNTIME)}` (114 entries; exact set match)")

    lux_rows = [line.split("\t", 1)[0] for line in LUX_TOKENS.read_text().splitlines() if "\t" in line]
    lux = {token for token in lux_rows if len(token) == 1}
    verification.append(f"LuxTTS pinned `tokens.txt`: `{sha256(LUX_TOKENS)}` ({len(lux_rows)} tokens; {len(lux)} raw single-scalar tokens)")

    style_path = FLUID / "Sources/FluidAudio/TTS/StyleTTS2/Pipeline/Tokenizer/StyleTTS2TextCleaner.swift"
    style = scalar_set(
        swift_string(style_path, "punctuation")
        + swift_string(style_path, "letters")
        + swift_string(style_path, "ipaLetters")
        + "$"
    )
    inflect_path = FLUID / "Sources/FluidAudio/TTS/Inflect/InflectSymbols.swift"
    inflect = scalar_set(
        swift_string(inflect_path, "pad")
        + swift_string(inflect_path, "punctuation")
        + swift_string(inflect_path, "letters")
        + swift_string(inflect_path, "lettersIPA")
    )
    wrapper_path = ROOT / "Sources/PhonemeSynthesizer/Backends.swift"
    wrapper_lux = scalar_set(swift_string(wrapper_path, "lux"))
    wrapper_inflect = scalar_set(swift_string(wrapper_path, "inflect"))
    if wrapper_lux != lux:
        raise RuntimeError("local Lux strict inventory differs from pinned tokens.txt")
    if wrapper_inflect != inflect:
        raise RuntimeError("local Inflect strict inventory differs from pinned symbol table")
    verification.append("Local strict wrappers: LuxTTS 159/159 exact match; Inflect v2 177/177 exact match")
    verification.append(f"FluidAudio revision: `{git_revision(FLUID)}`")
    verification.append(f"StyleTTS2 fixed symbol table: {len(style)} unique Unicode scalars")
    verification.append(f"Inflect v2 fixed symbol table: {len(inflect)} unique Unicode scalars")
    if TOUCAN_REPO.exists():
        revision = git_revision(TOUCAN_REPO)
        if revision != TOUCAN_REVISION:
            raise RuntimeError(f"installed IMS Toucan revision {revision} differs from audited {TOUCAN_REVISION}")
        tree = ast.parse((TOUCAN_REPO / "Preprocessing/articulatory_features.py").read_text())
        function = next(node for node in tree.body if isinstance(node, ast.FunctionDef) and node.name == "generate_feature_lookup")
        returned = next(node for node in ast.walk(function) if isinstance(node, ast.Return))
        direct = set(ast.literal_eval(returned.value).keys())
        if direct != TOUCAN_DIRECT:
            raise RuntimeError("audited Toucan direct symbol inventory differs from pinned source")
        verification.append(f"IMS Toucan installed source: `{revision}`; direct symbol table exact-match verified")
    verification.append(f"IMS Toucan articulatory audit revision: `{TOUCAN_REVISION}`; {len(TOUCAN_DIRECT)} direct symbols plus semantic modifiers/mappings")
    return {
        "Kokoro ANE": kokoro, "LuxTTS": lux, "StyleTTS2": style,
        "Inflect v2": inflect, "Toucan articulatory": TOUCAN_DIRECT,
    }, verification


BASE_SECTIONS = {
    "Pulmonic consonants": "p b t d ʈ ɖ c ɟ k ɡ q ɢ ʔ m ɱ n ɳ ɲ ŋ ɴ ʙ r ʀ ⱱ ɾ ɽ ɸ β f v θ ð s z ʃ ʒ ʂ ʐ ç ʝ x ɣ χ ʁ ħ ʕ h ɦ ɬ ɮ ʋ ɹ ɻ j ɰ l ɭ ʎ ʟ".split(),
    "Non-pulmonic consonants": "ʘ ǀ ǃ ǂ ǁ ɓ ɗ ʄ ɠ ʛ ʼ".split(),
    "Other IPA symbols": "ʍ w ɥ ʜ ʢ ʡ ɕ ʑ ɺ ɧ".split(),
    "Vowels": "i y ɨ ʉ ɯ u ɪ ʏ ʊ e ø ɘ ɵ ɤ o ə ɛ œ ɜ ɞ ʌ ɔ æ ɐ a ɶ ɑ ɒ".split(),
}

DIACRITICS = [
    ("Voiceless (below)", "̥"), ("Voiceless (above)", "̊"), ("Voiced", "̬"),
    ("Aspirated", "ʰ"), ("More rounded", "̹"), ("Less rounded", "̜"),
    ("Advanced", "̟"), ("Retracted", "̠"), ("Centralized", "̈"),
    ("Mid-centralized", "̽"), ("Syllabic", "̩"), ("Non-syllabic", "̯"),
    ("Rhoticity", "˞"), ("Breathy voiced", "̤"), ("Creaky voiced", "̰"),
    ("Linguolabial", "̼"), ("Labialized", "ʷ"), ("Palatalized", "ʲ"),
    ("Velarized", "ˠ"), ("Pharyngealized", "ˤ"), ("Velarized/pharyngealized", "̴"),
    ("Raised", "̝"), ("Lowered", "̞"), ("Advanced tongue root", "̘"),
    ("Retracted tongue root", "̙"), ("Dental", "̪"), ("Apical", "̺"),
    ("Laminal", "̻"), ("Nasalized", "̃"), ("Nasal release", "ⁿ"),
    ("Lateral release", "ˡ"), ("No audible release", "̚"),
    ("Tie bar above", "͡"), ("Tie bar below", "͜"),
]

SUPRASEGMENTALS = [
    ("Primary stress", "ˈ"), ("Secondary stress", "ˌ"), ("Long", "ː"),
    ("Half-long", "ˑ"), ("Extra-short", "̆"), ("Minor group", "|"),
    ("Major group", "‖"), ("Syllable break", "."), ("Linking", "‿"),
]

TONES = [
    ("Extra high tone letter", "˥"), ("High tone letter", "˦"),
    ("Mid tone letter", "˧"), ("Low tone letter", "˨"), ("Extra low tone letter", "˩"),
    ("Extra high tone diacritic", "̋"), ("High tone diacritic", "́"),
    ("Mid tone diacritic", "̄"), ("Low tone diacritic", "̀"), ("Extra low tone diacritic", "̏"),
    ("Rising", "̌"), ("Falling", "̂"), ("High rising", "᷄"),
    ("Low rising", "᷅"), ("Rising-falling", "᷈"), ("Downstep", "↓"),
    ("Upstep", "↑"), ("Global rise", "↗"), ("Global fall", "↘"),
]

WARNING_TOKENS = {
    ("Kokoro ANE", "̃"): "⚠",
    ("StyleTTS2", "̩"): "⚠",
}


def support_cell(backend: str, symbol: str, inventories: dict[str, set[str]]) -> str:
    if backend == "Toucan articulatory":
        if symbol in TOUCAN_FEATURE_MODIFIERS:
            return "F"
        if symbol in TOUCAN_MAPPED:
            return "M"
        if symbol in TOUCAN_CONTEXTUAL:
            return "C"
        return "T" if symbol in TOUCAN_DIRECT else "—"
    if symbol not in inventories[backend]:
        return "—"
    if (backend, symbol) in WARNING_TOKENS:
        return "⚠"
    return "T"


def codepoint(symbol: str) -> str:
    return " ".join(f"U+{ord(ch):04X}" for ch in symbol)


def display(symbol: str) -> str:
    if len(symbol) == 1 and unicodedata.category(symbol).startswith("M"):
        return "◌" + symbol
    if symbol == " ":
        return "SPACE"
    return symbol


def unicode_name(symbol: str) -> str:
    return " + ".join(unicodedata.name(ch, "UNNAMED") for ch in symbol)


def symbol_cell(symbol: str) -> str:
    if symbol == "|":
        return "<code>&#124;</code>"
    return f"`{display(symbol)}`"


def append_matrix(lines: list[str], rows: list[tuple[str, str]], inventories: dict[str, set[str]]) -> None:
    lines += ["| Symbol | Unicode | Description | Kokoro ANE | LuxTTS | StyleTTS2 | Inflect v2 | Toucan |", "|---|---|---|:---:|:---:|:---:|:---:|:---:|"]
    for description, symbol in rows:
        cells = [support_cell(name, symbol, inventories) for name in inventories]
        lines.append(f"| {symbol_cell(symbol)} | `{codepoint(symbol)}` | {description} | " + " | ".join(cells) + " |")
    lines.append("")


def main() -> None:
    inventories, verification = load_inventories()
    lines = [
        "# Phone symbol support",
        "",
        "This matrix describes raw `--ipa` input behavior for the synthesis backends pinned by this repository.",
        "The baseline is the International Phonetic Alphabet chart revised to 2020; backend-specific extensions are listed separately.",
        "",
        "## Legend",
        "",
        "- `T` — tokenized/reachable. This does **not** by itself prove correct IPA acoustic realization.",
        "- `F` — represented explicitly as an articulatory feature by Toucan (stronger semantic support than token presence).",
        "- `M` — our strict adapter maps the IPA symbol to an equivalent Toucan articulatory representation.",
        "- `C` — supported only in explicitly recognized contexts; bare use remains invalid.",
        "- `⚠` — token/vocabulary entry exists, but the pinned tokenizer loses it in normal use.",
        "- `—` — unsupported by the strict raw-phone path; it must error rather than be silently dropped.",
        "",
        "Reference conditioning is orthogonal to symbol support: LuxTTS and StyleTTS2 still require their normal reference-audio inputs. `T` never means “phonetically validated.”",
        "",
        "## Verification provenance",
        "",
    ]
    lines += [f"- {item}" for item in verification]
    lines += [
        "- IPA baseline: International Phonetic Association, official chart revised to 2020.",
        "- Kokoro combining-mark diagnostic: `KokoroAneVocab.encode(\"æ̃\")` produced only BOS/EOS even though `̃` exists in `vocab.json`.",
        "- StyleTTS2 combining-mark diagnostic: `StyleTTS2TextCleaner.dictionary[\"̩\"] == nil`; `n̩` encodes to no phoneme tokens.",
        "",
        "## Important compatibility findings",
        "",
        "1. **Kokoro does not natively support `˞` or `ɝ`.** Its own English G2P emits rhotic sequences such as `ɜɹ` and `əɹ`; `ɚ` is a native token.",
        "2. **LuxTTS supports `˞` but not `ɝ`.** It also has the broadest set of directly usable combining IPA diacritics here.",
        "3. **StyleTTS2 and Inflect v2 contain all 108 base IPA chart symbols**, including `ɝ` and `˞` as backend extensions, but StyleTTS2 has a combining-mark grapheme bug for syllabicity `̩`.",
        "4. **Kokoro's `̃` token is not effectively usable as a combining nasalization mark** in the pinned FluidAudio revision because its tokenizer iterates Swift `Character` grapheme clusters.",
        "5. **Toucan is different:** modifiers such as `ʰ`, `̃`, and `ʷ` mutate explicit articulatory features. Our adapter also provides strict equivalence mappings for `ɥ→jʷ`, `ⱱ→ѵ` (Toucan's labiodental-flap table typo), `ʲ→̧`, and `ˤ→ˁ`. We deliberately do not use Toucan's lossy text-frontend approximations for `ɬ`, `ɮ`, `ɺ`, or `ɧ`.",
        "6. **Acoustic validation is tracked separately from reachability.** For example, Inflect v2 `ʷ` has been synthesis-exercised (`ka` and `kʷa` produce different audio), but correct labialization has not yet been independently established.",
        "",
    ]
    base_all = {symbol for symbols in BASE_SECTIONS.values() for symbol in symbols}
    lines += ["## Base IPA symbols", ""]
    lines.append("Coverage across the 108 base consonant/vowel/other symbols on the IPA 2020 chart:")
    lines.append("")
    lines += ["| Backend | Supported | Missing |", "|---|---:|---|"]
    for backend, inventory in inventories.items():
        effective = inventory | (TOUCAN_BASE_ALIASES if backend == "Toucan articulatory" else set())
        missing = sorted(base_all - effective, key=lambda value: ord(value))
        lines.append(f"| {backend} | {len(base_all & effective)}/108 | `{' '.join(missing) if missing else '—'}` |")
    lines.append("")

    for section, symbols in BASE_SECTIONS.items():
        lines += [f"### {section}", ""]
        rows = [(unicode_name(symbol).title(), symbol) for symbol in symbols]
        append_matrix(lines, rows, inventories)

    lines += ["## IPA diacritics", ""]
    append_matrix(lines, DIACRITICS, inventories)
    lines += [
        "> `⚠` is materially different from `T`: the scalar exists in the vocabulary, but the current tokenizer loses it when attached to its base phone.",
        "",
        "## Suprasegmentals",
        "",
    ]
    append_matrix(lines, SUPRASEGMENTALS, inventories)
    lines += ["## Tones and word accents", ""]
    append_matrix(lines, TONES, inventories)

    official = base_all | {symbol for _, symbol in DIACRITICS + SUPRASEGMENTALS + TONES}
    extras = sorted(set().union(*inventories.values()) - official, key=lambda value: ord(value))
    lines += [
        "## Backend-specific and non-IPA raw tokens",
        "",
        "These are single-scalar tokens accepted by at least one backend but not a standalone symbol in the IPA 2020 baseline above. Some are espeak/training conventions, punctuation, control tokens, or language-specific extensions rather than phones.",
        "",
        "| Token | Unicode | Unicode name | Kokoro ANE | LuxTTS | StyleTTS2 | Inflect v2 | Toucan |",
        "|---|---|---|:---:|:---:|:---:|:---:|:---:|",
    ]
    for symbol in extras:
        cells = [support_cell(name, symbol, inventories) for name in inventories]
        lines.append(f"| {symbol_cell(symbol)} | `{codepoint(symbol)}` | {unicode_name(symbol).title()} | " + " | ".join(cells) + " |")
    lines.append("")

    lux_rows = [line.split("\t", 1)[0] for line in LUX_TOKENS.read_text().splitlines() if "\t" in line]
    multi = [token for token in lux_rows if len(token) != 1]
    lines += [
        "## LuxTTS multi-character tokens",
        "",
        f"The pinned LuxTTS vocabulary also contains **{len(multi)} multi-character Mandarin/pinyin tokens**. `LuxTtsTokenizer.tokenIds(phonemes:)`, which backs raw English/IPA input, tokenizes one Unicode scalar at a time, so these are **not addressable as atomic tokens through raw `--ipa` strings**. They are reachable only through the token-array API.",
        "",
        "```text",
    ]
    for start in range(0, len(multi), 20):
        lines.append(" ".join(multi[start:start + 20]))
    lines += ["```", ""]
    lines += [
        "## Rhotic input conventions",
        "",
        "| Form | Kokoro ANE | LuxTTS | StyleTTS2 | Inflect v2 | Toucan | Note |",
        "|---|:---:|:---:|:---:|:---:|:---:|---|",
        f"| `ɚ` | {support_cell('Kokoro ANE', 'ɚ', inventories)} | {support_cell('LuxTTS', 'ɚ', inventories)} | {support_cell('StyleTTS2', 'ɚ', inventories)} | {support_cell('Inflect v2', 'ɚ', inventories)} | M | Toucan preserves rhoticity as `əɹ`. |",
        f"| `ɝ` | {support_cell('Kokoro ANE', 'ɝ', inventories)} | {support_cell('LuxTTS', 'ɝ', inventories)} | {support_cell('StyleTTS2', 'ɝ', inventories)} | {support_cell('Inflect v2', 'ɝ', inventories)} | M | Toucan preserves rhoticity as `ɜɹ`. |",
        f"| `˞` | {support_cell('Kokoro ANE', '˞', inventories)} | {support_cell('LuxTTS', '˞', inventories)} | {support_cell('StyleTTS2', '˞', inventories)} | {support_cell('Inflect v2', '˞', inventories)} | C | Toucan accepts only known rhotic-vowel contexts (`ə˞`, `ɜ˞`); arbitrary `a˞` errors. |",
        "| `ɜɹ`, `əɹ` | T | T | T | T | T | Explicit segment sequences are directly representable. |",
        "",
        "For Kokoro, do **not** merely delete `˞`: that removes a phonetic contrast. Convert a known rhotic-vowel spelling to the model's actual phone convention (typically a vowel followed by `ɹ`) or use `ɚ` where appropriate.",
        "",
        "## Regeneration",
        "",
        "Run `python3 scripts/generate-phone-support.py` after resolving the pinned FluidAudio package. If the downloaded Kokoro runtime vocabulary is present, generation also verifies that its key set exactly matches the repository's strict Kokoro inventory.",
        "",
    ]
    OUT.write_text("\n".join(lines))
    print(f"wrote {OUT.relative_to(ROOT)} ({len(lines)} lines)")


if __name__ == "__main__":
    main()
