export type Invocation = { command: string; args: string[] };

export function benchmarkInvocation(binary: string | undefined, args: string[]): Invocation {
  if (binary) return { command: binary, args };
  return { command: "swift", args: ["run", "-c", "release", "phoneme-synth", ...args] };
}
