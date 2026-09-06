export function benchmarkScore(
  wer: number | null,
  cer: number | null,
  utmos: number | null,
  clipping: number,
  rtfx: number,
): number {
  let value = 100;
  if (wer != null) value -= Math.min(60, Math.max(0, wer) * 240);
  if (cer != null) value -= Math.min(25, Math.max(0, cer) * 250);
  value -= Math.min(10, Math.max(0, clipping) * 1000);
  if (utmos != null) value += Math.max(-5, Math.min(5, (utmos - 3.5) * 3.33));
  value += Math.min(2, Math.log2(Math.max(rtfx, 1)) * 0.4);
  return Math.min(100, Math.max(0, value));
}
