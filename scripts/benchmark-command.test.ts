import { describe, expect, test } from "bun:test";
import { benchmarkInvocation } from "./benchmark-command";

describe("benchmark command", () => {
  test("uses an explicit prebuilt binary when provided", () => {
    expect(benchmarkInvocation("/tmp/phoneme-synth", ["benchmark"])).toEqual({ command: "/tmp/phoneme-synth", args: ["benchmark"] });
  });

  test("falls back to swift run when no binary is provided", () => {
    expect(benchmarkInvocation(undefined, ["benchmark"])).toEqual({ command: "swift", args: ["run", "-c", "release", "phoneme-synth", "benchmark"] });
  });
});
