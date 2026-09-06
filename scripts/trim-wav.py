#!/usr/bin/env python3
import argparse
import wave

parser = argparse.ArgumentParser()
parser.add_argument("input")
parser.add_argument("output")
parser.add_argument("--seconds", type=float, required=True)
args = parser.parse_args()

with wave.open(args.input, "rb") as src:
    if src.getnchannels() != 1 or src.getsampwidth() != 2 or src.getframerate() != 24000:
        raise SystemExit("reference WAV must be 24 kHz mono PCM16")
    frames = src.readframes(src.getnframes())
    params = src.getparams()

target_frames = round(args.seconds * params.framerate)
target_bytes = target_frames * params.sampwidth
frames = frames[:target_bytes]
if len(frames) < target_bytes:
    frames += bytes(target_bytes - len(frames))

with wave.open(args.output, "wb") as dst:
    dst.setnchannels(1)
    dst.setsampwidth(2)
    dst.setframerate(24000)
    dst.writeframes(frames)
