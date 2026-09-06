import { describe, expect, test } from "bun:test";
import { utmosInvocation } from "./utmos-command";

describe("UTMOS batch command", () => {
  test("scores every backend with one evaluator process", () => {
    const invocation = utmosInvocation("abc123", "/tmp/out.json", [
      ["kokoro-ane", "/tmp/kokoro"],
      ["luxtts", "/tmp/lux"],
      ["toucan-articulatory", "/tmp/toucan"],
    ]);
    expect(invocation.command).toBe("uv");
    expect(invocation.args.filter(x => x === "--target")).toHaveLength(3);
    expect(invocation.args).toContain("kokoro-ane=/tmp/kokoro");
    expect(invocation.args).toContain("toucan-articulatory=/tmp/toucan");
    expect(invocation.args.join(" ")).toContain("UTMOSV2.git@abc123");
  });
});
