#!/usr/bin/env python3
import argparse
import json
import os
import tempfile
from pathlib import Path

import utmosv2


def parse_target(raw: str) -> tuple[str, Path]:
    label, separator, directory = raw.partition("=")
    if not separator or not label or not directory:
        raise argparse.ArgumentTypeError("target must be LABEL=DIRECTORY")
    path = Path(directory)
    if not path.is_dir():
        raise argparse.ArgumentTypeError(f"audio directory does not exist: {path}")
    return label, path


def normalized_rows(result) -> list[dict]:
    rows = []
    for item in result:
        if not isinstance(item, dict):
            raise RuntimeError(f"unexpected UTMOSv2 result: {item!r}")
        path = item.get("file_path") or item.get("path")
        score = item.get("predicted_mos") or item.get("mos") or item.get("score")
        if path is None or score is None:
            raise RuntimeError(f"incomplete UTMOSv2 result: {item!r}")
        rows.append({"file": Path(path).name, "utmos": float(score)})
    return rows


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", required=True)
    parser.add_argument("--target", action="append", required=True, type=parse_target)
    args = parser.parse_args()

    model = utmosv2.create_model(pretrained=True)
    report = {label: {"mean": None, "samples": []} for label, _ in args.target}
    with tempfile.TemporaryDirectory(prefix="utmos-batch-") as temp:
        staged = {}
        for label, directory in args.target:
            for wav in sorted(directory.glob("*.wav")):
                name = f"{label}__{wav.name}"
                os.symlink(wav.resolve(), Path(temp) / name)
                staged[name] = (label, wav.name)
        rows = normalized_rows(model.predict(input_dir=temp, device="cpu"))
        for row in rows:
            label, original = staged[row["file"]]
            report[label]["samples"].append({"file": original, "utmos": row["utmos"]})
    for value in report.values():
        scores = [row["utmos"] for row in value["samples"]]
        value["mean"] = sum(scores) / len(scores) if scores else None
    Path(args.output).write_text(json.dumps(report, indent=2) + "\n")


if __name__ == "__main__":
    main()
