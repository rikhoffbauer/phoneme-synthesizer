export type UTMOSTarget = readonly [label: string, directory: string];

export function utmosInvocation(
  revision: string,
  output: string,
  targets: readonly UTMOSTarget[],
): { command: string; args: string[] } {
  if (targets.length === 0) throw new Error("UTMOS requires at least one target");
  const args = [
    "run", "--python", "3.11",
    "--with", `utmosv2 @ git+https://github.com/sarulab-speech/UTMOSV2.git@${revision}`,
    "python", "scripts/score-utmos.py", "--output", output,
  ];
  for (const [label, directory] of targets) {
    args.push("--target", `${label}=${directory}`);
  }
  return { command: "uv", args };
}
