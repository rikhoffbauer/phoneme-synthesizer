import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { assertBenchmarkValid, parseBenchmarkMarkdown } from "./benchmark-report";

const root = resolve(import.meta.dir, "..");
const report = parseBenchmarkMarkdown(readFileSync(resolve(root, "BENCHMARK_RESULTS.md"), "utf8"));
assertBenchmarkValid(report);
console.log(`benchmark schema v${report.schema_version}: ${report.aggregate.backend} score=${report.aggregate.score.toFixed(2)}`);
