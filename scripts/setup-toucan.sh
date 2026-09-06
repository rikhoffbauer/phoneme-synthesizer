#!/bin/sh
set -eu

TOUCAN_REV="3cc2094d9c7123336eda7e299ac0bc90319ca9ff"
ROOT="${PHONEME_SYNTH_TOUCAN_ROOT:-$HOME/.cache/phoneme-synthesizer/toucan}"
REPO="$ROOT/IMS-Toucan"
VENV="$ROOT/.venv"
PYTHON_VERSION="${PHONEME_SYNTH_TOUCAN_PYTHON_VERSION:-3.10}"

command -v git >/dev/null 2>&1 || { echo "error: git is required" >&2; exit 1; }
command -v uv >/dev/null 2>&1 || { echo "error: uv is required (https://docs.astral.sh/uv/)" >&2; exit 1; }

mkdir -p "$ROOT"
if [ ! -d "$REPO/.git" ]; then
  git clone -q https://github.com/DigitalPhonetics/IMS-Toucan.git "$REPO"
fi

git -C "$REPO" fetch -q origin "$TOUCAN_REV"
git -C "$REPO" checkout -q --detach "$TOUCAN_REV"

if [ ! -x "$VENV/bin/python" ]; then
  uv venv --python "$PYTHON_VERSION" "$VENV"
fi

UV="uv pip install --python $VENV/bin/python"
$UV \
  'pip<25' \
  'setuptools<81' \
  'torch==2.4.0' \
  'torchaudio==2.4.0' \
  'numpy~=1.23.4' \
  'scipy~=1.9.3' \
  'librosa~=0.9.2' \
  'soundfile~=0.12.0' \
  'pyloudnorm~=0.1.0' \
  'speechbrain==0.5.13' \
  'phonemizer~=3.2.1' \
  'transphone==1.5.3' \
  'dragonmapper~=0.2.6' \
  'pypinyin~=0.47.1' \
  'praat-parselmouth~=0.4.2' \
  'dotwiz==0.4.0' \
  'einops==0.7.0' \
  'alias_free_torch~=0.0.6' \
  'huggingface-hub==0.25.2' \
  'imageio~=2.34.0' \
  'matplotlib~=3.9.2' \
  'sounddevice~=0.4.5'

printf 'Toucan installed at %s\n' "$ROOT"
printf 'Pinned IMS-Toucan revision: %s\n' "$TOUCAN_REV"
