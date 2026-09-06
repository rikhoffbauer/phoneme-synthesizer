import React, { useEffect, useMemo, useState } from "react";
import { createRoot } from "react-dom/client";
import { marked } from "marked";
import "./styles.css";

type Sample = {
  id: string; text: string; ipa: string; audio_file: string | null;
  synth_ms: number; audio_ms: number; rtfx: number;
  wer: number | null; cer: number | null; peak: number; rms: number;
  clipping_ratio: number; dc_offset: number;
};
type Report = {
  generated_at: string; profile: string;
  git: { tree: string; branch: string; commit: string | null };
  system: { hardware: string; os: string; arch: string };
  corpus: { path: string; sha256: string; samples: number };
  aggregate: { backend: string; score: number; wer: number | null; cer: number | null; utmos: number | null; rtfx: number; clipping_ratio: number; dc_offset: number };
  gates: { passed: boolean; failures: string[] };
  samples: Sample[];
};
type History = { commit: string; date: string; subject: string; backend: string; score: number; wer: number | null; cer: number | null; utmos: number | null; rtfx: number; passed: boolean; hardware: string }[];

const pct = (v: number | null, digits = 2) => v == null ? "—" : `${(v * 100).toFixed(digits)}%`;
const num = (v: number | null, digits = 2) => v == null ? "—" : v.toFixed(digits);
const short = (sha: string) => sha.slice(0, 8);

function Metric({ label, value, detail }: { label: string; value: string; detail?: string }) {
  return <div className="metric"><div className="metric-label">{label}</div><div className="metric-value">{value}</div>{detail && <div className="metric-detail">{detail}</div>}</div>;
}

function TrendChart({ history }: { history: History }) {
  const points = history.slice(-30);
  if (points.length < 2) return <div className="empty">Trend data appears after at least two benchmarked commits.</div>;
  const width = 900, height = 260, pad = 34;
  const scores = points.map(x => x.score);
  const min = Math.max(0, Math.min(...scores) - 3), max = Math.min(100, Math.max(...scores) + 3);
  const x = (i: number) => pad + (i / (points.length - 1)) * (width - pad * 2);
  const y = (v: number) => height - pad - ((v - min) / Math.max(1, max - min)) * (height - pad * 2);
  const path = points.map((p, i) => `${i ? "L" : "M"}${x(i).toFixed(1)},${y(p.score).toFixed(1)}`).join(" ");
  return <div className="chart-wrap"><svg viewBox={`0 0 ${width} ${height}`} role="img" aria-label="Benchmark score over commits">
    <line className="axis" x1={pad} y1={height - pad} x2={width - pad} y2={height - pad}/>
    <line className="axis" x1={pad} y1={pad} x2={pad} y2={height - pad}/>
    <path className="trend" d={path}/>
    {points.map((p, i) => <g key={`${p.commit}-${i}`}><circle className={p.passed ? "dot" : "dot failed"} cx={x(i)} cy={y(p.score)} r="5"><title>{`${short(p.commit)} · ${p.score.toFixed(2)} · ${p.subject}`}</title></circle></g>)}
    <text className="axis-label" x={pad} y={18}>{max.toFixed(0)}</text><text className="axis-label" x={pad} y={height - 8}>{min.toFixed(0)}</text>
  </svg></div>;
}

function Samples({ report }: { report: Report }) {
  return <div className="table-scroll"><table><thead><tr><th>Sample</th><th>IPA</th><th>Audio</th><th>WER</th><th>CER</th><th>RTFx</th><th>Peak</th></tr></thead><tbody>
    {report.samples.map(s => <tr key={s.id}><td><strong>{s.id}</strong><span>{s.text}</span></td><td className="ipa">{s.ipa}</td><td>{s.audio_file ? <audio controls preload="none" src={`./audio/${s.audio_file}`}/> : "—"}</td><td>{pct(s.wer)}</td><td>{pct(s.cer)}</td><td>{s.rtfx.toFixed(2)}×</td><td>{s.peak.toFixed(3)}</td></tr>)}
  </tbody></table></div>;
}

function App() {
  const [report, setReport] = useState<Report | null>(null);
  const [history, setHistory] = useState<History>([]);
  const [docs, setDocs] = useState("");
  const [tab, setTab] = useState<"results"|"history"|"docs">("results");
  useEffect(() => { Promise.all([
    fetch("./data/current.json").then(r => r.json()),
    fetch("./data/history.json").then(r => r.json()),
    fetch("./README.md").then(r => r.text()),
  ]).then(([r, h, d]) => { setReport(r); setHistory(h); setDocs(d); }); }, []);
  const docsHtml = useMemo(() => ({ __html: marked.parse(docs) as string }), [docs]);
  if (!report) return <main className="loading">Loading benchmark data…</main>;
  return <>
    <header><div><a className="brand" href="./">phoneme-synthesizer</a><span className="subtitle">benchmark ledger</span></div><nav>{(["results","history","docs"] as const).map(x => <button key={x} className={tab===x?"active":""} onClick={()=>setTab(x)}>{x}</button>)}</nav></header>
    <main>
      {tab === "results" && <>
        <section className="hero"><div><h1>Direct IPA in. Measured speech out.</h1><p>Every commit carries its own machine-readable benchmark result. Quality gates prioritize pronunciation fidelity before synthesis speed.</p></div><div className={`gate ${report.gates.passed ? "pass" : "fail"}`}>{report.gates.passed ? "Gates passed" : "Regression detected"}</div></section>
        <section className="metrics"><Metric label="Composite score" value={report.aggregate.score.toFixed(2)} detail="0–100"/><Metric label="WER" value={pct(report.aggregate.wer)} detail="ASR round-trip"/><Metric label="CER" value={pct(report.aggregate.cer)} detail="ASR round-trip"/><Metric label="RTFx" value={`${report.aggregate.rtfx.toFixed(2)}×`} detail="audio / synthesis time"/><Metric label="UTMOS" value={num(report.aggregate.utmos,3)} detail="full profile"/></section>
        {!report.gates.passed && <section className="failures"><strong>Failed gates</strong><ul>{report.gates.failures.map(x => <li key={x}>{x}</li>)}</ul></section>}
        <section><div className="section-head"><div><h2>Current corpus</h2><p>{report.corpus.samples} fixed samples · {report.aggregate.backend} · {report.system.hardware}</p></div><code>{short(report.git.tree)}</code></div><Samples report={report}/></section>
      </>}
      {tab === "history" && <><section className="section-head"><div><h1>Benchmark history</h1><p>Reconstructed from immutable <code>BENCHMARK_RESULTS.md</code> files across git history.</p></div></section><TrendChart history={history}/><div className="history-list">{[...history].reverse().map(h => <article key={h.commit}><div><code>{short(h.commit)}</code><strong>{h.score.toFixed(2)}</strong><span>{h.subject}</span></div><div><span>{pct(h.wer)} WER</span><span>{h.rtfx.toFixed(2)}× RTFx</span><span>{new Date(h.date).toISOString().slice(0,10)}</span></div></article>)}</div></>}
      {tab === "docs" && <article className="docs" dangerouslySetInnerHTML={docsHtml}/>} 
    </main>
    <footer><span>Profile {report.profile}</span><span>{new Date(report.generated_at).toISOString()}</span><span>{report.system.arch}</span></footer>
  </>;
}

createRoot(document.getElementById("root")!).render(<App/>);
