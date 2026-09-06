#!/usr/bin/env python3
import contextlib
import json
import os
import random
import sys
import time
from pathlib import Path

PROTOCOL_OUT = sys.stdout


def emit(payload):
    PROTOCOL_OUT.write(json.dumps(payload, ensure_ascii=False) + "\n")
    PROTOCOL_OUT.flush()


def fail(request_id, error):
    emit({"id": request_id, "ok": False, "error": str(error)})


def main():
    repo = Path(os.environ["PHONEME_SYNTH_TOUCAN_REPO"]).expanduser().resolve()
    if not repo.is_dir():
        raise RuntimeError(f"IMS-Toucan checkout not found: {repo}")
    os.chdir(repo)
    sys.path.insert(0, str(repo))
    with contextlib.redirect_stdout(sys.stderr):
        import numpy as np
        import soundfile as sf
        import torch
        from InferenceInterfaces.ToucanTTSInterface import ToucanTTSInterface

        device = os.environ.get("PHONEME_SYNTH_TOUCAN_DEVICE", "cpu")
        model = ToucanTTSInterface(device=device, language="eng")

    emit({"ready": True, "sample_rate": 24000, "device": device})

    for raw_line in sys.stdin:
        if not raw_line.strip():
            continue
        request_id = None
        try:
            request = json.loads(raw_line)
            request_id = request.get("id")
            ipa = request["ipa"]
            output = Path(request["output"]).expanduser().resolve()
            speed = float(request.get("speed", 1.0))
            seed = int(request.get("seed", 0))
            if speed <= 0:
                raise ValueError("speed must be greater than zero")

            random.seed(seed)
            np.random.seed(seed & 0xFFFFFFFF)
            torch.manual_seed(seed)
            with contextlib.redirect_stdout(sys.stderr):
                # Fail closed: verify every phone/modifier is representable before synthesis.
                model.text2phone.string_to_tensor(
                    ipa,
                    device=device,
                    handle_missing=False,
                    input_phonemes=True,
                )
                started = time.perf_counter()
                wave, sample_rate = model(
                    ipa,
                    input_is_phones=True,
                    duration_scaling_factor=1.0 / speed,
                )
                synthesis_seconds = time.perf_counter() - started

            output.parent.mkdir(parents=True, exist_ok=True)
            sf.write(str(output), wave, sample_rate, subtype="PCM_16")
            emit({
                "id": request_id,
                "ok": True,
                "sample_rate": int(sample_rate),
                "synthesis_seconds": synthesis_seconds,
            })
        except Exception as error:
            fail(request_id, error)


if __name__ == "__main__":
    main()
