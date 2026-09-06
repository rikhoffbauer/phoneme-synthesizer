#!/usr/bin/env python3
import argparse
import json
from pathlib import Path
import utmosv2

parser = argparse.ArgumentParser()
parser.add_argument("audio_dir")
parser.add_argument("output")
args = parser.parse_args()

model = utmosv2.create_model(pretrained=True)
result = model.predict(input_dir=args.audio_dir)
rows = []
for item in result:
    if isinstance(item, dict):
        path = item.get("file_path") or item.get("path")
        score = item.get("predicted_mos") or item.get("mos") or item.get("score")
    else:
        raise RuntimeError(f"unexpected UTMOSv2 result: {item!r}")
    rows.append({"file": Path(path).name, "utmos": float(score)})
Path(args.output).write_text(json.dumps(rows, indent=2) + "\n")
